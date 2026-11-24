---@meta

---@param desc string
---@param fn fun()
function describe(desc, fn) end

---@param desc string
---@param fn fun()
function it(desc, fn) end

---@param fn fun()
function before_each(fn) end

---@param fn fun()
function after_each(fn) end

---@class BustedAssertAre
---@field same fun(expected: any, actual: any, message?: string)
---@field equal fun(expected: any, actual: any, message?: string)

---@class BustedAssert
---@field are BustedAssertAre
---@field is_true fun(value: any, message?: string)
---@field is_false fun(value: any, message?: string)
---@field is_nil fun(value: any, message?: string)
---@field is_not_nil fun(value: any, message?: string)
assert = assert
