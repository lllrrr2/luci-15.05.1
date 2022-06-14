module("luci.controller.alist", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/alist") then
		return
	end
	entry({"admin", "nas", "alist"}, cbi("alist"), _("Alist"), 20).dependent = true
	entry({"admin", "nas", "alist_status"}, call("alist_status"))
end

function alist_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get_first("alist", "alist", "port"))
	local rpassword
	local password = io.popen("logread | grep alist | grep password | grep -v local | tail -n 1 | awk '{print $12}'")

	local status = {
		running = (sys.call("pidof alist >/dev/null") == 0),
		port = (port or 5244),
		rpassword = string.gsub(password:read("*a"), "\n",  "")	
	}

	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end

