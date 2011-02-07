--[[
Copyright (c) 2011 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local floor = math.floor
local min, max = math.min, math.max
module(..., package.seeall)
local Class = require(_PACKAGE .. 'class')
local vector = require(_PACKAGE .. 'vector')
_M.class = nil
_M.vector = nil

-- special cell accesor metamethods, so vectors are converted
-- to a string before using as keys
local cell_meta = {}
function cell_meta.__newindex(tbl, key, val)
	return rawset(tbl, key.x..","..key.y, val)
end
function cell_meta.__index(tbl, key)
	local key = key.x..","..key.y
	local ret = rawget(tbl, key)
	if not ret then
		ret = setmetatable({}, {__mode = "kv"})
		rawset(tbl, key, ret)
	end
	return ret
end

Spatialhash = Class{name = 'Spatialhash', function(self, cell_size)
	self.cell_size = cell_size or 100
	self.cells = setmetatable({}, cell_meta)
end}

function Spatialhash:cellCoords(v)
	return {x=floor(v.x / self.cell_size), y=floor(v.y / self.cell_size)}
end

function Spatialhash:cell(v)
	return self.cells[ self:cellCoords(v) ]
end

function Spatialhash:insert(obj, ul, lr)
	local ul = self:cellCoords(ul)
	local lr = self:cellCoords(lr)
	for i = ul.x,lr.x do
		for k = ul.y,lr.y do
			rawset(self.cells[ {x=i,y=k} ], obj, obj)
		end
	end
end

function Spatialhash:remove(obj, ul, lr)
	-- no bbox given. => must check all cells
	if not ul or not lr then
		for _,cell in pairs(self.cells) do
			rawset(cell, obj, nil)
		end
		return
	end

	local ul = self:cellCoords(ul)
	local lr = self:cellCoords(lr)
	-- else: remove only from bbox
	for i = ul.x,lr.x do
		for k = ul.y,lr.y do
			rawset(self.cells[{x=i,y=k}], obj, nil)
		end
	end
end

-- update an objects position
function Spatialhash:update(obj, ul_old, lr_old, ul_new, lr_new)
	local ul_old, lr_old = self:cellCoords(ul_old), self:cellCoords(lr_old)
	local ul_new, lr_new = self:cellCoords(ul_new), self:cellCoords(lr_new)

	local xmin, xmax = min(ul_old.x, ul_new.x), max(lr_old.x, lr_new.x)
	local ymin, ymax = min(ul_old.y, ul_new.y), max(lr_old.y, lr_new.y)

	if xmin == xmax and ymin == ymax then return end

	for i = xmin,xmax do
		for k = ymin,ymax do
			local region_old = i >= ul_old.x and i <= lr_old.x and k >= ul_old.y and k <= lr_old.y
			local region_new = i >= ul_new.x and i <= lr_new.x and k >= ul_new.y and k <= lr_new.y
			if region_new and not region_old then
				self.cells[{x=i,y=k}][obj] = obj
			elseif not region_new and region_old then
				self.cells[{x=i,y=k}][obj] = nil
			end
		end
	end
end

function Spatialhash:getNeighbors(obj, ul, lr)
	local ul = self:cellCoords(ul)
	local lr = self:cellCoords(lr)
	local set,items = {}, {}
	for i = ul.x,lr.x do
		for k = ul.y,lr.y do
			local cell = self.cells[{x=i,y=k}] or {}
			for other,_ in pairs(cell) do
				if obj ~= other then
					rawset(set, other, true)
				end
			end
		end
	end
	local i = 1
	for other,_ in pairs(set) do
		items[i] = other
		i = i + 1
	end
	return items
end

-- module() as shortcut to module.Spatialhash()
do
	local m = getmetatable(_M)
	m.__call = function(_, ...) return Spatialhash(...) end
end
