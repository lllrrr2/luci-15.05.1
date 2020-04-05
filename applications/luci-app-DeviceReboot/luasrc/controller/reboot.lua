
module("luci.controller.reboot", package.seeall)

function index()
   entry({"admin", "services", "reboot"}, cbi("reboot/settings"), _("Device Reboot"), 90)
end

function action_reboot()
	local set = luci.http.formvalue("set")
	if set then
		luci.sys.reboot()
	end
end
