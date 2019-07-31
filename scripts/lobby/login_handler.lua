local handler = {}

function handler.QueryRole(message, client)
	local app = client.app
	app.logger:trace("QueryRole:"..message.accountid)
	local sql = string.format("select roleid, rolename from t_character where accountid=%d", 
				message.accountid);
	app.dbpool:execute(1, sql, function(ecode, emsg, result)
		if ecode ~= 0 then
			app.logger:error("ex:"..sql ", error:"..emsg)
			return
		end
		
		local res = {accountid = message.accountid, role_ids={}, role_names={}}
		for i, v in pairs(result) do
			table.insert(res.role_ids, v["roleid"])
			table.insert(res.role_names, v["rolename"])
		end
		
		app:send_msg(client.csocket, "lobby.QueryRoleRes", res)
	end)
end

function handler.CreateRole(message, client)
	local app = client.app
	app.logger:trace("QueryRole:"..message.accountid)
	local newroleid = app.mroleid + 1
	app.mroleid = newroleid
	local sql = string.format("insert into t_character (roleid, accountid, rolename, profession, create_time) value (%d, %d, '%s', %d, now())",
							newroleid, message.accountid, message.name, message.profession)
	app.dbpool:execute(1, sql, function(ecode, emsg, result)
		local err_code = 0
		local roleid = 0
		if ecode ~= 0 then
			err_code = app:enum("common.ErrorCode", "ERR_ROLENAME")
			app.logger:error("ex:"..sql.." faild, err: "..emsg)
		else
			roleid = newroleid
		end
		
		local msg = {error_code=err_code, accountid=message.accountid, role_id=roleid, role_name=message.name}
		app:send_msg(client.csocket, "lobby.CreateRoleRes", msg)
	end)
end

function handler.EnterLobby(message, client)
	local app = client.app
	app.logger:trace("EnterLobby: "..message.accountid..":"..message.roleid)
	local sql = string.format("select roleid, accountid, rolename, profession, mapid, posx, posy, attack, blood, defense, glod, grade, mana, speed, exp from t_character where roleid=%d",
								message.roleid)
	local accountid = 0
	local rolename = ""
	local profession = 0
	local mapid = 0
	local attack = 0
	local blood = 0
	local defense = 0
	local glod = 0
	local grade = 0
	local mana = 0
	local speed = 0
	local exp = 0
	local posx = 0
	local posy = 0

	sql = app.dbpool:execute(1, sql, function(ecode, emsg, result)
		if ecode ~= 0 then
			app.logger:error("ex:"..sql.." faild, err:"..emsg)
			return
		end

		if #result == 0 then
			app.logger:error("enter lobby cant find role:"..message.roleid)
			return
		end

		accountid = tonumber(result[1]["accountid"])
		rolename = result[1]["rolename"]
		profession = tonumber(result[1]["profession"])
		mapid = tonumber(result[1]["mapid"])
		attack = tonumber(result[1]["attack"])
		blood = tonumber(result[1]["blood"])
		defense = tonumber(result[1]["defense"])
		glod = tonumber(result[1]["glod"])
		grade = tonumber(result[1]["grade"])
		mana = tonumber(result[1]["mana"])
		speed = tonumber(result[1]["speed"])
		exp = tonumber(result[1]["exp"])
		posx = tonumber(result[1]["posx"])
		posy = tonumber(result[1]["posy"])

		local player = app.playermgr:create_player(tonumber(result[1]["accountid"]), message.roleid, result[1]["rolename"])
		player.profession = profession
		player.mapid = mapid
		player.attack = attack
		player.blood = blood
		player.defense = defense
		player.glod = glod
		player.grade = grade
		player.mana = mana
		player.speed = speed
		player.exp = exp
		player.gateserverid = client.id
		player.x = posx
		player.y = posy

		local msg = {
				roleid=message.roleid, 
				accountid=accountid, 
				rolename=rolename,
				profession=profession,
				mapid=mapid,
				attack=attack,
				blood=blood,
				defense=defense,
				glod=glod,
				grade=grade,
				mana=mana,
				speed=speed,
				exp=exp,
				posx = posx,
				posy = posy}

		app:send_msg(client.csocket, "lobby.EnterLobbyRes", msg)		
	end)
end

function handler.LoadComplete(message, client)
	local app = client.app
	app.logger:trace("load complete..."..message.accountid)
	local player = app.playermgr:get_player_by_accid(message.accountid)
	assert(player ~= nil)
	app:emit("enter_"..player.mapid, player)
end

function handler.MoveReq(message, client)
	local app = client.app
	app.logger:trace("MoveReq")
	local player = app.playermgr:get_player_by_accid(message.accountid)
	assert(player ~= nil)

	player.x = message.posx
	player.y = message.posy

	local scene = app.scenes[player.mapid]
	scene:send_to_view(player, "lobby.MoveRes", {moverid=player.roleid, posx = player.x, posy = player.y})
end

return {
	package = "lobby",
	handler = handler
}