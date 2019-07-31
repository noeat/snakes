require "common.class"

local Pool = class(function(self, maxn)
	self.maxn = maxn
	self.nextid = 1
	self.ids = {}
	for i = 1, maxn , 1 do
		table.insert(self.ids, 0)
	end
end)

function Pool:malloc(begpos)
	local beg = begpos or self.nextid
	local ret = -1
	for i = 0, self.maxn-1, 1 do
		local n = 1 + math.mod(beg + i, self.maxn)
		if self.ids[n] == 0 then
			self.ids[n] = 1
			ret = n
			self.nextid = n
			break
		end
	end
	
	return ret
end

function Pool:free(id)
	assert(self.ids[id] == 1)
	self.ids[id] = 0
end

return Pool