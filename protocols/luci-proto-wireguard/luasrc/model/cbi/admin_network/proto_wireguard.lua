-- Copyright 2016-2017 Dan Luedtke <mail@danrl.com>
-- Licensed to the public under the Apache License 2.0.


local map, section, net = ...
local ifname = net:get_interface():name()
local private_key, listen_port
local metric, mtu, preshared_key


-- key generation function
local function generate_key_pair()
  local util = require("luci.util")

-- Generate private key and preshared key separately
  local private_cmd = util.exec("wg genkey 2>/dev/null")
  local preshared_cmd = util.exec("wg genkey 2>/dev/null")

  local private = ""
  local preshared = ""
  local public = ""
  
-- Process private key and generate public key
  if private_cmd and #private_cmd > 0 then
    private = private_cmd:gsub("\n", "")
    public = util.exec("echo -n '" .. private .. "' | wg pubkey 2>/dev/null")
    public = public:gsub("\n", "")
  end
  
-- Process preshared key
  if preshared_cmd and #preshared_cmd > 0 then
    preshared = preshared_cmd:gsub("\n", "")
  end

  return private, public, preshared
end


-- Secure JSON string escaping function
local function escape_json_string(s)
  if not s then return "" end
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return s
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
  local private, public, preshared = generate_key_pair()
  if private and public then
    luci.http.prepare_content("text/html")
    luci.http.write([[
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>]] .. translate("WireGuard Keys Generated") .. [[</title>
    <style>
      body { font-family: 'Helvetica', Arial, sans-serif; padding:30px; background:#f9f9f9; color:#333; line-height: 1.6; }
      h3 { color:#0066cc; margin-bottom:20px; font-size: 24px; }
      .key-box { background:#fff; border:1px solid #ccc; border-radius:4px; padding:15px; 
                margin:15px 0; font-family:monospace; word-break:break-all; color: #000000; box-shadow: inset 0 1px 3px rgba(0,0,0,0.1); }
      .warning { background:#fff3cd; border:1px solid #ffc107; color:#856404; 
                 padding:10px; border-radius:4px; margin:15px 0; }
      .key-label { font-weight: bold; margin-bottom: 5px; color: #444444; font-size: 16px; }
      .private-key { background:#fff0f0; border-color:#dc3545; }
      .private-key { background:#f0f7ff; border-color:#0066cc; }
      button { background:#0066cc; color:white; border:none; padding:10px 20px; 
               border-radius:4px; margin:5px; cursor:pointer; transition: background 0.3s; }
      button:hover { background:#0052a3; }
      button.copy { background:#28a745; }
      button.copy:hover { background: #218838; }
      .note { color: #666666; font-size: 13px; margin-top: 5px; margin-bottom: 20px; }
      .key-container { margin-bottom: 25px; }
      .key-box { background: #ffffff; border: 1px solid #cccccc; border-radius: 4px; padding: 15px; margin: 10px 0; font-family: monospace; font-size: 14px; word-break: break-all; color: #000000; }
    </style>
    <script>
    var keyData = {
      private: "]] .. escape_json_string(private) .. [[",
      public: "]] .. escape_json_string(public) .. [[",
      preshared: "]] .. escape_json_string(preshared) .. [["
    };
    
    function copyToClipboard(type) {
      var text = type === 'private' ? keyData.private : 
                  (type === 'public' ? keyData.public : keyData.preshared);
      var textarea = document.createElement('textarea');
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      
      var btn = event.target;
      var originalText = btn.innerHTML;
      btn.innerHTML = '✓ ]] .. translate("Copied!") .. [[';
      setTimeout(function() {
        btn.innerHTML = originalText;
      }, 1500);
    }
    
    function closeWindow() { window.close(); }
    
    window.onload = function() {
      document.getElementById('private_key_display').textContent = keyData.private;
      document.getElementById('public_key_display').textContent = keyData.public;
      document.getElementById('preshared_key_display').textContent = keyData.preshared;
    };
    </script>
    </head>
    <body>
      <h3>🔑 ]] .. translate("WireGuard Keys Generated") .. [[</h3>
      <div class="warning"><strong>⚠️ ]] .. translate("Private Key MUST be kept secret!") .. [[</strong></div>
      
      <div class="key-container">
        <div class="key-label">🔒 ]] .. translate("Private Key (SECRET - Keep safe!)") .. [[</div>
        <div class="key-box private-key" id="private_key_display"></div>
        <button class="copy" onclick="copyToClipboard('private')">📋 ]] .. translate("Copy Private Key") .. [[</button>
      </div>
      
      <div class="key-container">
        <div class="key-label">🔓 ]] .. translate("Public Key (Share with peers)") .. [[</div>
        <div class="key-box" id="public_key_display"></div>
        <button class="copy" onclick="copyToClipboard('public')">📋 ]] .. translate("Copy Public Key") .. [[</button>
      </div>

      <div class="key-container">
        <div class="key-label">🔐 ]] .. translate("Preshared Key (Optional - Extra security)") .. [[</div>
        <div class="key-box preshared-key" id="preshared_key_display"></div>
        <button class="copy" onclick="copyToClipboard('preshared')">📋 ]] .. translate("Copy Preshared Key") .. [[</button>
        <div class="note">]] .. translate("Preshared key adds post-quantum resistance. Share with peer securely.") .. [[</div>
      </div>
      
      <p style="text-align:center; margin-top:30px;">
        <button class="close" onclick="closeWindow()">✖ ]] .. translate("Close Window") .. [[</button>
      </p>
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

-- Stylish separator for Peer Configuration
local peer_separator = section:taboption("general", DummyValue, "_peer_separator")
peer_separator.title = " "
peer_separator.rawhtml = true
peer_separator.value = [[
<div style="margin:30px 0 20px 0; width:100%; display:flex; justify-content:left;">
  <div style="display:inline-block; background:linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
              padding:15px 40px; border-radius:50px; box-shadow:0 4px 15px rgba(0,0,0,0.2);
              border:2px solid #fff;">
    <span style="font-size:18px; font-weight:bold; color:white; text-shadow:1px 1px 2px rgba(0,0,0,0.3);
                 letter-spacing:1px;">
      ⚡ ]] .. translate("PEER CONFIGURATION") .. [[ ⚡
    </span>
  </div>
</div>
<div style="width:100%; text-align:left; margin-bottom:20px;">
  <span style="color:#666; font-size:14px;">
    ]] .. translate("Configure the remote peer connection settings below") .. [[
  </span>
</div>
]]

-- Peer Public Key
local peer_public = section:taboption(
  "general",
  Value,
  "peer_public_key",
  translate("Peer Public Key"),
  translate("Required. Public key of the remote peer you want to connect to.")
)
peer_public.datatype = "rangelength(44, 44)"
peer_public.optional = false
peer_public.rmempty = true

-- Peer Allowed IPs
local peer_allowed_ips = section:taboption(
  "general",
  DynamicList,
  "peer_allowed_ips",
  translate("Peer Allowed IPs"),
  translate("IP addresses that this peer is allowed to use. ") ..
  translate("Example: 10.0.0.2/32 for a single IP, or 0.0.0.0/0 to route all traffic through this peer.")
)
peer_allowed_ips.datatype = "ipaddr"
peer_allowed_ips.optional = false
peer_allowed_ips.rmempty = false

-- Peer Endpoint
local peer_endpoint = section:taboption(
  "general",
  Value,
  "peer_endpoint",
  translate("Peer Endpoint"),
  translate("Optional. Address of the remote peer. ") ..
  translate("Format: host:port (e.g., vpn.example.com:51820 or [2001:db8::1]:51820). ") ..
  translate("Leave empty if this peer will initiate the connection to you.")
)
peer_endpoint.placeholder = "vpn.example.com:51820"
peer_endpoint.optional = true

-- Peer Keep Alive
local peer_keepalive = section:taboption(
  "general",
  Value,
  "peer_persistent_keepalive",
  translate("Keep Alive"),
  translate("Optional. Send keep-alive packets every N seconds. ") ..
  translate("Set to 25 if peer is behind NAT. Set to 0 to disable.")
)
peer_keepalive.datatype = "range(0, 65535)"
peer_keepalive.placeholder = "25"
peer_keepalive.optional = true
peer_keepalive.default = "0"

-- Route Allowed IPs flag
local route_allowed_ips = section:taboption(
  "general",
  Flag,
  "route_allowed_ips",
  translate("Route Allowed IPs"),
  translate("Optional. Create routes for Allowed IPs for this peer.")
)


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
mtu.datatype = "range(1280,1420)"
mtu.placeholder = "1420"
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

-- Modern IPv6 support notice
local ipv6_note = section:taboption("general", DummyValue, "_ipv6_note")
ipv6_note.title = " "
ipv6_note.rawhtml = true
ipv6_note.value = function()
  return [[
  <div style="margin:20px 0 10px 0; padding:15px; background:linear-gradient(135deg, #f5f7fa 0%, #e4e8f0 100%);
              border-left:4px solid #0066cc; border-radius:4px; box-shadow:0 2px 5px rgba(0,0,0,0.1);">
    <div style="display:flex; align-items:center;">
      <div style="font-size:24px; margin-right:15px;">🌐</div>
      <div>
        <strong style="color:#0066cc; font-size:16px;">]] .. translate("IPv6 Support") .. [[</strong>
        <p style="margin:5px 0 0 0; color:#444;">
          ]] .. translate("IPv6 addresses are fully supported. Use them to connect devices without public IPv4.") .. [[
        </p>
      </div>
    </div>
  </div>
  ]]
end
