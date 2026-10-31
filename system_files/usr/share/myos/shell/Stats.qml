pragma Singleton

// 「このPC」ウィジェット用の数値：CPU 使用率、メモリ使用率、GPU 温度、ホームの空き容量
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0          // 0〜1
    property real memory: 0       // 0〜1
    property int gpuTemp: -1      // ℃。取れなければ -1
    property real diskFree: 0     // バイト
    property real diskTotal: 1

    property var previousCpu: null

    Process {
        id: readCpuMemory
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCpuMemory(this.text)
        }
    }

    Process {
        id: readGpu
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(this.text);
                root.gpuTemp = isNaN(value) ? -1 : value;
            }
        }
    }

    Process {
        id: readDisk
        command: ["sh", "-c", "df -B1 --output=avail,size \"$HOME\" | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                if (parts.length === 2) {
                    root.diskFree = Number(parts[0]);
                    root.diskTotal = Math.max(1, Number(parts[1]));
                }
            }
        }
    }

    function parseCpuMemory(text) {
        const lines = text.split("\n");
        const cpuFields = lines[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = cpuFields[3] + (cpuFields[4] || 0);
        const total = cpuFields.reduce((sum, value) => sum + value, 0);
        if (previousCpu) {
            const totalDelta = total - previousCpu.total;
            const idleDelta = idle - previousCpu.idle;
            if (totalDelta > 0)
                cpu = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta));
        }
        previousCpu = { total: total, idle: idle };

        let memTotal = 0, memAvailable = 0;
        for (const line of lines) {
            if (line.startsWith("MemTotal:"))
                memTotal = Number(line.split(/\s+/)[1]);
            if (line.startsWith("MemAvailable:"))
                memAvailable = Number(line.split(/\s+/)[1]);
        }
        if (memTotal > 0)
            memory = 1 - memAvailable / memTotal;
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: readCpuMemory.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: readGpu.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: readDisk.running = true
    }
}
