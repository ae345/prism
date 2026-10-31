// 「このPC」ウィジェット：CPU・メモリ・GPU 温度・空き容量
import QtQuick

Glass {
    id: root

    Grid {
        anchors.centerIn: parent
        columns: 2
        rowSpacing: 14
        columnSpacing: 14

        Ring {
            label: "CPU"
            value: Stats.cpu
            valueText: Math.round(Stats.cpu * 100) + "%"
            color: Theme.green
        }

        Ring {
            label: "メモリ"
            value: Stats.memory
            valueText: Math.round(Stats.memory * 100) + "%"
            color: Theme.cyan
        }

        Ring {
            label: "GPU"
            value: Stats.gpuTemp < 0 ? 0 : Stats.gpuTemp / 100
            valueText: Stats.gpuTemp < 0 ? "—" : Stats.gpuTemp + "°"
            color: Theme.orange
        }

        Ring {
            label: "空き"
            value: Stats.diskFree / Stats.diskTotal
            valueText: Stats.diskFree >= 1e12
                ? (Stats.diskFree / 1e12).toFixed(1) + "T"
                : Math.round(Stats.diskFree / 1e9) + "G"
            color: Theme.violet
        }
    }
}
