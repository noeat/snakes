require "common.class"
local EventEmitter = require "common.eventemitter"
local LinkList = require "common.linklist"

local Scene = class(EventEmitter, function(self, app, mapid)
	self.app = app
	self.mapid = mapid
	self.xaix = LinkList()
	self.yaix = LinkList()
	self.players = {}

	self.app:on("enter_"..mapid, function(player)
		self:on_enter(player)
		self.app.logger:info("enter scene:"..player.rolename)
	end)

	self.app:on("leave_"..mapid, function(player)
		self:on_leave(player)
		self.app.logger:info("leave scene:"..player.rolename)
	end)
	self.app.logger:info("scene:"..self.mapid.." open.")
end)

function Scene:on_enter(player)
	if self.players[player.roleid] ~= nil then
		self:leave(player)
	end

	self:enter(player)
end

function Scene:on_leave(player)
	self:leave(player)
end

function Scene:leave(player)
	if self.players[player.roleid] ~= nil then
		local other_list = self:get_eyes(player)
		for _, v in pairs(other_list) do
			v:send_msg("lobby.LeaveSight", {roleid=player.roleid})
			player:send_msg("lobby.LeaveSight", {roleid=v.roleid})
		end

		local localtion = self.players[player.roleid]
		self.xaix:delete_node(localtion.xaix)
		self.yaix:delete_node(localtion.yaix)
		self.players[player.roleid] = nil
	end
end

function Scene:get_eyes(player)
	assert(self.players[player.roleid] ~= nil)
	local localtion = self.players[player.roleid]
	local other_list = {}
	for v in self.xaix:aiter(self.xaix.head) do
		print(v.ele.rolename, v.order)
	end

	for v in self.xaix:aiter(localtion.xaix) do
		if v.order - localtion.xaix.order < player.eye and other_list[v.ele.roleid] == nil then
			other_list[v.ele.roleid] = v.ele
		end
	end
	
	for v in self.xaix:biter(localtion.xaix) do
		print(localtion.xaix.order - v.order)
		print(player.eye)
		if localtion.xaix.order - v.order < player.eye and other_list[v.ele.roleid] == nil then
			other_list[v.ele.roleid] = v.ele
		end
	end

	for v in self.yaix:aiter(localtion.yaix) do
		if other_list[v.ele.roleid] == nil and v.order - localtion.yaix.order < player.eye then
			other_list[v.ele.roleid] = v.ele
		end
	end

	for v in self.yaix:biter(localtion.yaix) do
		print(localtion.yaix.order - v.order)
		if other_list[v.ele.roleid] == nil and localtion.yaix.order - v.order < player.eye then
			other_list[v.ele.roleid] = v.ele
		end
	end

	return other_list
end

function Scene:enter(player)
	assert(self.players[player.roleid] == nil)
	local localtion = {xaix = nil, yaix = nil}
	localtion.xaix = self.xaix:insert(player.x, player)
	localtion.yaix = self.yaix:insert(player.y, player)
	self.players[player.roleid] = localtion

	local other_list = self:get_eyes(player)
	for i, v in pairs(other_list) do
		local self_sight = {
			mapid = self.mapid,
			roleid=player.roleid, 
			rolename=player.rolename,
			profession=player.profession,
			posx = player.x,
			posy = player.y,
			blood = player.blood,
			speed = player.speed}

		local other_sight = {
			mapid = self.mapid,
			roleid=v.roleid, 
			rolename=v.rolename,
			profession=v.profession,
			posx = v.x,
			posy = v.y,
			blood = v.blood,
			speed = v.speed}

		print("aaaaaaaaaaa")

		player:send_msg("lobby.EnterSight", other_sight)
		v:send_msg("lobby.EnterSight", self_sight)
	end	
end

function Scene:move(player, xlen, ylen)
	assert(self.players[player.roleid] ~= nil)
	local old_list = self:get_eyes(player)
	local localtion = self.players[player.roleid]
	self.xaix:move(localtion.xaix, xlen)
	self.yaix:move(localtion.yaix, ylen)
	local new_list = self:get_eyes(player)

	for i, v in pairs(old_list) do
		if new_list[i] == nil then
			-- todo leave sight
			player:send_msg("lobby.LeaveSight", { roleid=v.roleid})
			v:send_msg("lobby.LeaveSight", { roleid=player.roleid})
		end
	end

	for i, v in pairs(new_list) do
		if old_list[i] == nil then
			-- todo enter sight
			local self_sight = {
				mapid = self.mapid,
				roleid=player.roleid, 
				rolename=player.rolename,
				profession=player.profession,
				posx = player.x,
				posy = player.y,
				blood = player.blood,
				speed = player.speed}

			local other_sight = {
				mapid = self.mapid,
				roleid=v.roleid, 
				rolename=v.rolename,
				profession=v.profession,
				posx = v.x,
				posy = v.y,
				blood = v.blood,
				speed = v.speed}

		player:send_msg("lobby.EnterSight", other_sight)
		v:send_msg("lobby.EnterSight", self_sight)
		end
	end
end

function Scene:send_to_view(player, msgname, message)
	local list = self:get_eyes(player)
	for i, v in pairs(list) do
		v:send_msg(msgname, message)
	end
end

return Scene