-- Copyright 2016-2017 Dan Luedtke <mail@danrl.com>
-- Licensed to the public under the Apache License 2.0.


local map, section, net = ...
local ifname = net:get_interface():name()
local private_key, listen_port
local metric, mtu, preshared_key, peers, public_key, allowed_ips, endpoint, persistent_keepalive


-- key generation function
local function generate_key_pair()
  local util = require("luci.util")
  local private = util.exec("wg genkey 2>/dev/null")
  local public = ""
  if private and #private > 0 then
    private = private:gsub("\n", "")
    public = util.exec("echo -n '" .. private .. "' | wg pubkey 2>/dev/null")
    public = public:gsub("\n", "")
  end
  return private, public
end


-- general ---------------------------------------------------------------------

private_key = section:taboption(
  "general",
  Value,
  "private_key",
  translate("Private Key"),
  translate("Required. Base64-encoded private key for this interface.")
)
private_key.password = true
private_key.datatype = "rangelength(44, 44)"
private_key.optional = false


-- generate keys button
local gen_btn = section:taboption("general", Button, "_generate")
gen_btn.title = " "
gen_btn.inputtitle = translate("Generate Keys")
gen_btn.inputstyle = "apply"
gen_btn.write = function()
  local private, public = generate_key_pair()
  if private and public then
    luci.http.prepare_content("text/html")
    luci.http.write([[
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>]] .. translate("WireGuard Keys Generated") .. [[</title>
    <style>
      body { font-family:sans-serif; padding:30px; background:#f9f9f9; color:#333; }
      .key-box { background:#fff; border:1px solid #ccc; border-radius:4px; padding:15px; margin:15px 0; font-family:monospace; word-break:break-all; }
      .warning { background:#fff3cd; border:1px solid #ffc107; color:#856404; padding:10px; border-radius:4px; }
      button { background:#0066cc; color:white; border:none; padding:10px 20px; border-radius:4px; margin:5px; cursor:pointer; }
    </style>
    <script>
    function copyToClipboard(text) {
      var textarea = document.createElement('textarea');
      textarea.value = text; document.body.appendChild(textarea);
      textarea.select(); document.execCommand('copy');
      document.body.removeChild(textarea);
      alert(']] .. translate("Copied!") .. [[');
    }
    function closeWindow() { window.close(); }
    </script>
    </head>
    <body>
      <h3>🔑 ]] .. translate("WireGuard Keys Generated") .. [[</h3>
      <div class="warning"><strong>⚠️ ]] .. translate("Private Key MUST be kept secret!") .. [[</strong></div>
      <div><strong>🔒 ]] .. translate("Private Key:") .. [[</strong></div>
      <div class="key-box">]] .. private .. [[</div>
      <button onclick="copyToClipboard(']] .. private .. [[')">📋 ]] .. translate("Copy Private Key") .. [[</button>
      <div style="margin-top:20px;"><strong>🔓 ]] .. translate("Public Key:") .. [[</strong></div>
      <div class="key-box">]] .. public .. [[</div>
      <button onclick="copyToClipboard(']] .. public .. [[')">📋 ]] .. translate("Copy Public Key") .. [[</button>
      <p><button onclick="closeWindow()">✖ ]] .. translate("Close") .. [[</button></p>
    </body>
    </html>
    ]])
  end
end


listen_port = section:taboption(
  "general",
  Value,
  "listen_port",
  translate("Listen Port"),
  translate("Optional. UDP port used for outgoing and incoming packets.")
)
listen_port.datatype = "port"
listen_port.placeholder = "51820"
listen_port.optional = true

addresses = section:taboption(
  "general",
  DynamicList,
  "addresses",
  translate("IP Addresses"),
  translate("Recommended. IP addresses of the WireGuard interface.")
)
addresses.datatype = "ipaddr"
addresses.optional = true


-- advanced --------------------------------------------------------------------

metric = section:taboption(
  "advanced",
  Value,
  "metric",
  translate("Metric"),
  translate("Optional")
)
metric.datatype = "uinteger"
metric.placeholder = "0"
metric.optional = true


mtu = section:taboption(
  "advanced",
  Value,
  "mtu",
  translate("MTU"),
  translate("Optional. Maximum Transmission Unit of tunnel interface.")
)
mtu.datatype = "range(1280,1423)"
mtu.placeholder = "1423"
mtu.optional = true


preshared_key = section:taboption(
  "advanced",
  Value,
  "preshared_key",
  translate("Preshared Key"),
  translate("Optional. Adds in an additional layer of symmetric-key " ..
            "cryptography for post-quantum resistance.")
)
preshared_key.password = true
preshared_key.datatype = "rangelength(44, 44)"
preshared_key.optional = true


-- peers -----------------------------------------------------------------------

peers = map:section(
  TypedSection,
  "wireguard_" .. ifname,
  translate("Peers"),
  translate("Further information about WireGuard interfaces and peers " ..
            "at <a href=\"http://wireguard.io\">wireguard.io</a>.")
)
peers.template = "cbi/tsection"
peers.anonymous = true
peers.addremove = true


public_key = peers:option(
  Value,
  "public_key",
  translate("Public Key"),
  translate("Required. Public key of peer.")
)
public_key.datatype = "rangelength(44, 44)"
public_key.optional = false


allowed_ips = peers:option(
  DynamicList,
  "allowed_ips",
  translate("Allowed IPs"),
  translate("Required. IP addresses and prefixes that this peer is allowed " ..
            "to use inside the tunnel. Usually the peer's tunnel IP " ..
            "addresses and the networks the peer routes through the tunnel.")
)
allowed_ips.datatype = "ipaddr"
allowed_ips.optional = false


route_allowed_ips = peers:option(
  Flag,
  "route_allowed_ips",
  translate("Route Allowed IPs"),
  translate("Optional. Create routes for Allowed IPs for this peer.")
)


endpoint_host = peers:option(
  Value,
  "endpoint_host",
  translate("Endpoint Host"),
  translate("Optional. Host of peer. Names are resolved " ..
            "prior to bringing up the interface."))
endpoint_host.placeholder = "vpn.example.com"
endpoint_host.datatype = "host"


endpoint_port = peers:option(
  Value,
  "endpoint_port",
  translate("Endpoint Port"),
  translate("Optional. Port of peer."))
endpoint_port.placeholder = "51820"
endpoint_port.datatype = "port"


persistent_keepalive = peers:option(
  Value,
  "persistent_keepalive",
  translate("Persistent Keep Alive"),
  translate("Optional. Seconds between keep alive messages. " ..
            "Default is 0 (disabled). Recommended value if " ..
            "this device is behind a NAT is 25."))
persistent_keepalive.datatype = "range(0, 65535)"
persistent_keepalive.placeholder = "0"
