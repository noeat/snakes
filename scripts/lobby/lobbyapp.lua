require "common.class"
local EventEmitter = require("common.eventemitter")
local Socket = require("lobby.socket")
local Scene = require("lobby.scene")

local LobbyApp = class(EventEmitter, function(self)
	self.type = Server.type()
    self.id   = Server.id()
    self.host = Server.host()
	self.port = Server.port()
	
	self.logger = {}
    local system_log = string.format("%s_%d", self.type, self.id)
    self.logger = CLogger.new(system_log, true, true, 2)
	
	self.pbcodec = require("libs.pbcodec")
    self.pbcodec:reset()
    self.pbcodec:add_pb_path({"./proto"})
    self.pbcodec:load_file("common.proto")
    self.pbcodec:load_file("server_common.proto")	
end)

function LobbyApp:main()
    self.pbcodec:load_file("lobby.proto")
	self.sockets = {}
	
	self.dbpool = CMySqlProxy.new("127.0.0.1", 3306, "root", "123456", "lobby", "utf8", 1)
	assert(self.dbpool:count() == 1, "dbpool init failed")
	self.logger:info("connect db 127.0.0.1:3306:lobby success")
	
	local result = self.dbpool:sync_execute(1, "select IFNULL(max(roleid), 1000) as mroleid from t_character")
	if result.eno ~= 0 then
		error("error ex: select max(roleid) from t_character, "..result.errMsg)
	end
	
	self.mroleid = result.results[1]["mroleid"]
	self.logger:info("mroleid: "..self.mroleid)
	
	local GateMgr = require("lobby.gatemgr")
	self.gatemgr = GateMgr(self)

	local PlayerMgr = require("lobby.playermanager")
	self.playermgr = PlayerMgr(self)

	self.scenes = {}
	for i =1, 5, 1 do
		self.scenes[i] = Scene(self, i)
	end
end

function LobbyApp:on_connect(csocket)
	local sid = csocket:get_sid()
	assert(self.sockets[sid] == nil)
	self.sockets[sid] = Socket(csocket, app)
end

function LobbyApp:on_close(csocket)
	local sid = csocket:get_sid()
	assert(self.sockets[sid] ~= nil)
	local socket = self.sockets[sid]
	socket:emit("on_close")
end

function LobbyApp:on_message(csocket, data)
	local sid = csocket:get_sid()
	assert(self.sockets[sid] ~= nil)
	local socket = self.sockets[sid]
	local pbHead = self.pbcodec:decode("common.MsgHead", data)
	if pbHead == nil or pbHead.proto == nil or pbHead.proto == "" then
		self.loggererror("decode message head failed")
		return
    end
	
	socket:emit("on_message", pbHead.proto, pbHead.data)
end

function LobbyApp:send_msg(csocket, msgname, msg)
    local dataBytes = self.pbcodec:encode(msgname, msg)
	local headBytes = self.pbcodec:encode("common.MsgHead", {proto = msgname, data = dataBytes})
	csocket:send(headBytes)
end

function LobbyApp:enum(etype, ev)
	return self.pbcodec.pb.enum(etype, ev)
end


return LobbyApp