--[[
	RateLimiter
	Token bucket per player per key. Used to throttle every client -> server remote.
]]

local Players = game:GetService("Players")

local RateLimiter = {}

local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

-- Returns true when the request is allowed. `rate` tokens per second, `burst` max tokens.
function RateLimiter.Check(player: Player, key: string, rate: number, burst: number): boolean
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local b = perPlayer[key]
	if not b then
		b = { tokens = burst, last = now }
		perPlayer[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimiter
