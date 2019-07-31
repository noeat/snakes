require "common.class"
local Queue = class(function(self, cap)
	self.begindex = 0
	self.endindex = 0
	self.data = {}
	self.cap = cap or 100
end)

function Queue:empty()
	return self.begindex == self.endindex
end

function Queue:push(ele)
	local endindex = math.mod(self.endindex + 1, self.cap)
	assert(endindex ~= self.begindex, "Queue cap too samll")
	self.data[self.endindex] = ele
	self.endindex = endindex	
end

function Queue:pop()
	assert(self:empty() == false, "queue is empty, cant pop")
	local data = self.data[self.begindex]
	self.data[self.begindex] = nil
	self.begindex = math.mod(self.begindex + 1, self.cap)
	return data
end

return Queue
