require "common.class"
local Player = require "lobby.player"

local PlayerMgr = class(function(self, app)
	self.app = app
	self.playersbyaccid = {}
	self.playersbyroleid ={}
end)

function PlayerMgr:create_player(accid, roleid, rolename)
	local player = Player(self.app)
	player.roleid = roleid
	player.accountid = accid
	player.rolename = rolename
	assert(self.playersbyaccid[accid] == nil)
	assert(self.playersbyroleid[roleid] == nil)
	self.playersbyaccid[accid] = player
	self.playersbyroleid[roleid] = player
	return player
end

function PlayerMgr:player_exit(accid)
	local player = self.playersbyaccid[accid]
	if player ~= nil then
		player:exit()
		self.playersbyaccid[accid] = nil
		self.playersbyroleid[player.roleid] = nil
	end
end

function PlayerMgr:get_player_by_roleid(roleid)
	return self.playersbyroleid[roleid]
end

function PlayerMgr:get_player_by_accid(accid)
	return self.playersbyaccid[accid]
end

return PlayerMgr