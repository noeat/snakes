require "common.class"
local EventEmitter = require("common.eventemitter")
local LoginApp = class(EventEmitter, function(self)
	self.type = Server.type()
    self.id   = Server.id()
    self.host = Server.host()
	
	self.logger = {}
    local system_log = string.format("%s_%d", self.type, self.id)
    self.logger = CLogger.new(system_log, true, true, 2)
	
	self.pbcodec = require("libs.pbcodec")
    self.pbcodec:reset()
    self.pbcodec:add_pb_path({"./proto"})
    self.pbcodec:load_file("common.proto")
    self.pbcodec:load_file("server_common.proto")
	
	self.servers = {}
	self.clients = {}
	self.sessionkey = {}
end)

function LoginApp:main()
   self.pbcodec:load_file("login.proto")
   --self.pbcodec.protoc:load("syntax = \"proto3\"; package login; message Test { int32 id = 1; }")
   self.dbpool = CMySqlProxy.new("127.0.0.1", 3306, "root", "123456", "lobby", "utf8", 1)

   --local bytes = self.pbcodec:encode("login.Test", {id=22222})
   --local msg = self.pbcodec:decode("login.Test", bytes)
   --print(msg.id)

   CTimer.new(1000, 0, function() 
		local now = CUtils.millisecond()
		for i, v in pairs(self.sessionkey) do
			if now - v.logintime > 10000 then
				print(now)
				print(v.logintime)
				self.sessionkey[i] = nil
			end
		end
		
		collectgarbage('collect')
		return true
   end)
end

function LoginApp:on_connect(csocket)
	local stype = csocket:stype()
	if stype == 1 or stype == 3 then
		self:on_server_connect(csocket)
	elseif stype == 2 then
		self:on_client_connect(csocket)
	else
		error("connect error socket type "..stype)
	end
	self.logger:info("on_connect:"..csocket:get_sid().. " "..stype)
end

function LoginApp:on_server_connect(csocket)
	local identity = {name=self.type, id=self.id}
	self:send_msg(csocket, "common.server.Identity", identity)
end

function LoginApp:on_client_connect(csocket)
	local sid = csocket:get_sid()
	assert(self.clients[sid] == nil)
	self.clients[sid] = csocket
end

function LoginApp:on_close(csocket)
	local stype = csocket:stype()
	local sid = csocket:get_sid()
	if stype == 2 then
		self.clients[sid] = nil
	elseif stype == 1 or stype == 3 then
		for i, v in pairs(self.servers) do
			if v.sid == sid then
				self.servers[i] = nil
			end
		end
	else
		error("close error socket type"..stype)
	end
	self.logger:info("on_close:"..csocket:get_sid().. " "..stype)
end

function LoginApp:on_message(csocket, data)
	local pbHead = self.pbcodec:decode("common.MsgHead", data)
	if pbHead == nil or pbHead.proto == nil or pbHead.proto == "" then
		self.logger:error("decode message head failed")
		return
    end
	
    local message = self.pbcodec:decode(pbHead.proto, pbHead.data)
	if message == nil then
		self.logger:error("decode message:"..pbHead.proto.." faild")
		return
	end
	
	if pbHead.proto == "common.server.Identity" then		
		assert(self.servers[message.id] == nil)
		self.servers[message.id] = {sid = csocket:get_sid(), socket=csocket, server_type=message.name}
	elseif pbHead.proto == "login.RegisterReq" then
		self:handle_registerReq(csocket, message)		
	elseif pbHead.proto == "login.LoginReq" then	
		self:handle_loginReq(csocket, message)
	elseif pbHead.proto == "common.server.GateInfoNotice" then
		self:handle_gateinfo_notice(message)
	elseif pbHead.proto == "common.server.AuthSession" then
		self:handle_authsession(csocket, message)
	else
		error("unknow msg "..pbHead.proto)
	end   
end

function LoginApp:handle_registerReq(csocket, message)
	self.logger:info("handle_registerReq account:"..message.account)
    local sql = string.format("insert into t_account \
        (accountname, accountpwd, register_time) \
        value('%s', '%s', NOW())", message.account, message.passwd)
    self.dbpool:execute(1, sql, function(errcode, errmsg, result)
		local error_code = 0
        if errcode ~= 0 then
            error_code = self:enum("common.ErrorCode", "ERR_REPEATED")    
            self.logger:error("execute sql:"..sql.." error:"..errmsg)        
        else
			error_code = self:enum("common.ErrorCode", "ERR_SUCCESS")
        end
        self:send_msg(csocket, "login.RegisterRes", {errcode=error_code}) 
    end)
end

function LoginApp:handle_loginReq(csocket, message)
	self.logger:info("handle_loginReq account:"..message.account)
	local sql = string.format("select accountid from t_account where accountname = '%s' and accountpwd= '%s'", 
		self.dbpool:escape(message.account), self.dbpool:escape(message.passwd))
	self.dbpool:execute(1, sql, function(ecode, emsg, result)
		if ecode ~= 0 then
			self.logger:error("execute sql:"..sql.." error:"..emsg)
			return
		end
		
		local error_code = 0
		local accid = 0
		error_code = self:enum("common.ErrorCode", "ERR_ACCOUNTORPASSWD")
		if #result ~= 0 then
			error_code = 0
			accid = tonumber(result[1]["accountid"])
		end		
		print("accid:"..accid)
		self:send_msg(csocket, "login.LoginRes", {errcode=error_code, accountid=accid})
		
		if error_code == 0 then
			self:send_gate_info(csocket, accid)
		end
	end)
end

function LoginApp:send_msg(csocket, msgname, msg)
    local dataBytes = self.pbcodec:encode(msgname, msg)
	local headBytes = self.pbcodec:encode("common.MsgHead", {proto = msgname, data = dataBytes})
	csocket:send(headBytes)
end

function LoginApp:send_gate_info(csocket, accountid)
	local session_key = tostring(CUtils.random(200000, 2000000))
	self.sessionkey[accountid] = {sessionkey=session_key, logintime=CUtils.millisecond()}
	print("pppp:", self.sessionkey[accountid])
	local gate_info = {sessionkey=session_key, list={server_lists={}}}
	local now = CUtils.millisecond()
	for i, v in pairs(self.servers) do
		if v.server_type == "gate" and v.reporttime ~= nil then
			local gate = {gate_host=v.host, gate_port=v.port}
			if now - v.reporttime > 60000 then
				gate.server_status = self:enum("common.ServerStatus", "STATUS_MAINTAIN")
			elseif v.online_num > 300 then
				gate.server_status = self:enum("common.ServerStatus", "STATUS_HOT")
			else
				gate.server_status = self:enum("common.ServerStatus", "STATUS_NORMAL")
			end
			
			table.insert(gate_info.list.server_lists, gate)
		end
	end
	self:send_msg(csocket, "login.EnterGateInfo", gate_info)
end

function LoginApp:handle_gateinfo_notice(message)
	self.logger:info("handle_gateinfo_notice ")
	local server_id = message.serverid
	if self.servers[server_id] ~= nil then
		local server = self.servers[server_id]
		assert(server.server_type == "gate")		
		server.host = message.gate_host
		server.port = message.gate_port
		server.online_num = message.onlinenum
		server.reporttime = CUtils.millisecond()
	end
end

function LoginApp:handle_authsession(csocket, message)
	self.logger:info("handle_authsession")
	
	print(message.sessionkey)
	print(message.accountid)
	print(self.sessionkey[message.accountid])
	print(self.sessionkey[message.accountid].sessionkey)
	local errcode = self:enum("common.ErrorCode", "ERR_AUTHFAILED")
	if self.sessionkey[message.accountid] ~= nil then
		if self.sessionkey[message.accountid].sessionkey == tostring(message.sessionkey) then
			errcode = 0
		else
			
			errcode = self:enum("common.ErrorCode", "ERR_SESSIONKEY")
		end
	end
	
	self:send_msg(csocket, "common.server.AuthSessionRep", 
	{error_code=errcode, accountid=message.accountid})
end

function LoginApp:enum(etype, ev)
	return self.pbcodec.pb.enum(etype, ev)
end

return LoginApp