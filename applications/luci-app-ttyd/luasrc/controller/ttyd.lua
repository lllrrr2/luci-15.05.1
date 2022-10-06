module("luci.controller.ttyd", package.seeall)

function index()
	if not (luci.sys.call("pidof ttyd > /dev/null") == 0) then
		return
	end

	entry({"admin", "system", "ttyd"}, template("ttyd/terminal"), _("TTYD Terminal"), 10).leaf = true
end
