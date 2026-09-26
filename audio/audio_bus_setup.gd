class_name AudioBusSetup
extends RefCounted

## Audio Bus を用意する（要件定義 §97 / §100）。
##
## BGM と SE を別の Bus にしておくと、音量設定（#52）がそのまま効く。
## Bus Layout のファイルを置く代わりに、無ければ実行時に作る。
##
## 状態を持たないので全て static。

## BGM の Bus 名。
const BGM_BUS: String = "BGM"

## SE の Bus 名。
const SE_BUS: String = "SE"


## BGM / SE の Bus が無ければ作る。作った数を返す。
static func ensure_buses() -> int:
	var created: int = 0
	for bus_name in [BGM_BUS, SE_BUS]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index: int = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		created += 1
	return created


## その Bus があるかを返す。
static func has_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0
