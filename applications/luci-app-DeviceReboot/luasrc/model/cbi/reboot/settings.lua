
local dayList = { "Monday", "Tuesday", "Wedesday", "Thursday", "Friday", "Saturday" }

m = Map("reboot", translate("Device Reboot"), 
	translate("set a reboot timer"))

s = m:section(TypedSection, "reboot", translate("Reboot Timer"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("Enabled"))

o = s:option(ListValue, "hour", translate("Hour"))
for i = 0, 23 do
	o:value(i, i)
end

o = s:option(ListValue, "min", translate("Minutes"))
for i = 0, 59 do
	o:value(i, i)
end

o = s:option(DummyValue, "_systime", translate("Local Time"))
o.template = "admin_system/clock_status"

o = s:option(MultiValue, "period", translate("Period"))
o:value(0, translate("Sunday"))
for _, d in ipairs(dayList) do
	o:value(_, translate(d))
end

return m
