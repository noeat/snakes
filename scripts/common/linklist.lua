require "common.class"

local LinkNode = class(function(self, order, ele)
	self.order = order
	self.ele = ele

	self.prev = nil
	self.next = nil
end)

local LinkList = class(function(self)
	self.head = LinkNode(-1, nil)
end)

function LinkList:insert(order, ele)
	local node = self.head
	local newnode = LinkNode(order, ele)
	while node.next ~= nil do
		if node.next.order > order then
			local newnode = LinkNode(order, ele)
			local oldnode = node.next
			node.next = newnode
			newnode.prev = node

			oldnode.prev = newnode
			newnode.next = oldnode
			return newnode
		else
			node = node.next
		end
	end

	node.next = newnode
	newnode.prev = node
	return newnode
end

function LinkList:insert_after(pos, node)
	node.next = pos.next
	if pos.next ~= nil then
		pos.next.prev = node
	end
	pos.next = node
	node.prev = pos
end

function LinkList:insert_before(pos, node)
	pos.prev.next = node
	node.next = pos
	node.prev = pos.prev
	pos.prev = node
end

function LinkList:delete_node(node)
	node.prev.next = node.next
	if node.next ~= nil then
		node.next.prev = node.prev
	end
end

function LinkList:move(node, x)	
	node.order = node.order + x
	if x > 0 then
		while node.next ~= nil and node.next.order < node.order do
			local next = node.next
			self:delete_node(node)
			self:insert_after(next, node)
		end
	else
		while node.prev ~= self.head and node.prev.order > node.order do
			local prev = node.prev
			self:delete_node(node)
			self:insert_before(prev, node)
		end
	end
end

function LinkList:biter(node)
	local n = node
	return function()
		n = ((n.prev == self.head) and {} or {n.prev})[1]
		return n
	end
end

function LinkList:aiter(node)
	local n = node
	return function()
		n = n.next
		return n
	end
end

return LinkList