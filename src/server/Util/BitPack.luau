--!strict
-- Packs several small non-negative integers into one saved number (D80:
-- "minimal bitpacking now" for small per-player fields).
--
-- Uses plain arithmetic instead of bit32 because bit32 stops at 32 bits,
-- while Luau numbers hold whole numbers exactly up to 2^53.

export type Field = { Name: string, Bits: number, Owner: string }
export type Slot = { Offset: number, Bits: number, Max: number, Owner: string }
export type Layout = { [string]: Slot }

local SAFE_BITS = 53 -- whole numbers are exact up to 2^53 in a double

local BitPack = {}

-- Turns an ordered field list into name -> slot. Errors on a bad layout, so a
-- Config typo stops the server at startup instead of corrupting saves.
function BitPack.layout(fields: { Field }): Layout
	local layout: Layout = {}
	local offset = 0
	for _, field in fields do
		assert(field.Bits >= 1 and field.Bits == math.floor(field.Bits), `BitPack: bad bit width for {field.Name}`)
		assert(layout[field.Name] == nil, `BitPack: duplicate field {field.Name}`)
		layout[field.Name] = { Offset = offset, Bits = field.Bits, Max = 2 ^ field.Bits - 1, Owner = field.Owner }
		offset += field.Bits
	end
	assert(offset <= SAFE_BITS, `BitPack: layout uses {offset} bits, more than {SAFE_BITS}`)
	return layout
end

function BitPack.get(word: number, slot: Slot): number
	return math.floor(word / 2 ^ slot.Offset) % 2 ^ slot.Bits
end

-- Returns the new word, and true if `value` had to be clamped into range.
function BitPack.set(word: number, slot: Slot, value: number): (number, boolean)
	local clean = math.floor(value)
	local clamped = false
	if clean ~= clean then -- NaN
		clean, clamped = 0, true
	elseif clean < 0 then
		clean, clamped = 0, true
	elseif clean > slot.Max then
		clean, clamped = slot.Max, true
	end
	local old = BitPack.get(word, slot)
	return word + (clean - old) * 2 ^ slot.Offset, clamped
end

-- Quick sanity check, run at startup in Studio (there's no test runner).
function BitPack.selfTest()
	local layout = BitPack.layout({
		{ Name = "A", Bits = 17, Owner = "test" },
		{ Name = "B", Bits = 17, Owner = "test" },
		{ Name = "C", Bits = 17, Owner = "test" },
	})
	local word = 0
	word = BitPack.set(word, layout.A, layout.A.Max)
	word = BitPack.set(word, layout.B, 12345)
	word = BitPack.set(word, layout.C, 1)
	assert(BitPack.get(word, layout.A) == layout.A.Max, "BitPack self-test: A")
	assert(BitPack.get(word, layout.B) == 12345, "BitPack self-test: B")
	assert(BitPack.get(word, layout.C) == 1, "BitPack self-test: C")

	local over, clamped = BitPack.set(word, layout.B, layout.B.Max + 5)
	assert(clamped and BitPack.get(over, layout.B) == layout.B.Max, "BitPack self-test: clamp high")
	assert(BitPack.get(over, layout.A) == layout.A.Max and BitPack.get(over, layout.C) == 1, "BitPack self-test: neighbors")

	local zeroed = BitPack.set(over, layout.A, 0)
	assert(BitPack.get(zeroed, layout.A) == 0 and BitPack.get(zeroed, layout.C) == 1, "BitPack self-test: overwrite")
	local _, negClamped = BitPack.set(zeroed, layout.A, -3)
	assert(negClamped, "BitPack self-test: clamp low")
	print("[BitPack] self-test passed")
end

return BitPack
