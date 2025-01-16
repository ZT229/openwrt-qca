#!/usr/bin/env ucode
import { readfile } from "fs";
import * as uci from 'uci';

const bands_order = [ "6G", "5G", "2G" ];
const htmode_order = [ "EHT", "HE", "VHT", "HT" ];

let board = json(readfile("/etc/board.json"));
if (!board.wlan)
	exit(0);

let idx = 0;
let commit;

let config = uci.cursor().get_all("wireless") ?? {};

function radio_exists(path, macaddr, phy) {
	for (let name, s in config) {
		if (s[".type"] != "wifi-device")
			continue;
        if (s.macaddr && lc(s.macaddr) == lc(macaddr))
			return true;
		if (s.phy == phy)
			return true;
		if (!s.path || !path)
			continue;
		if (substr(s.path, -length(path)) == path)
			return true;
	}
}

for (let phy_name, phy in board.wlan) {
	let info = phy.info;
	if (!info || !length(info.bands))
		continue;

		while (config[`radio${idx}`])
			idx++;
    let name = "radio" + idx++;

		let s = "wireless." + name;
		let si = "wireless.default_" + name;

    let band_name = filter(bands_order, (b) => info.bands[b])[0];
		if (!band_name)
			continue;

		let band = info.bands[band_name];
    	let channel = band.default_channel ?? "auto";

		let width = band.max_width;
		if (band_name == "2G")
        	width = 40;  // 默认开启 2.4G 的 HE40
    	else if (band_name == "5G")
        	width = 80;  // 默认开启 5G 的 HE160
		else if (width > 80)
			width = 80;

		let htmode = filter(htmode_order, (m) => band[lc(m)])[0];
		if (htmode)
			htmode += width;
		else
			htmode = "NOHT";

		if (!phy.path)
			continue;

		let macaddr = trim(readfile(`/sys/class/ieee80211/${phy_name}/macaddress`));
    	if (radio_exists(phy.path, macaddr, phy_name))
			continue;

		let id = `phy='${phy_name}'`;
		if (match(phy_name, /^phy[0-9]/))
			id = `path='${phy.path}'`;

		band_name = lc(band_name);

    	let country = 'CN';  // 设置默认国家为CN

    	// 分别为 2.4G 和 5G 设置不同的 SSID
    	let ssid = band_name === '2g' ? 'AX1800_2.4G' : 'AX1800_5G';

		print(`set ${s}=wifi-device
set ${s}.type='mac80211'
set ${s}.${id}
set ${s}.band='${band_name}'
set ${s}.channel='${channel}'
set ${s}.htmode='${htmode}'
set ${s}.country='${country}'
set ${s}.mu_beamformer='1'  # 默认开启 MU-MIMO
set ${s}.disabled='0'

set ${si}=wifi-iface
set ${si}.device='${name}'
set ${si}.network='lan'
set ${si}.mode='ap'
set ${si}.ssid='${ssid}'
set ${si}.encryption='sae'
set ${si}.key='qtxyz050618ZTzt.'
set ${si}.disabled='0'

`);
		commit = true;
}

if (commit)
	print("commit wireless\n");