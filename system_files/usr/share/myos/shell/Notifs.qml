pragma Singleton

// 通知の受け取り口。届いた通知は Hyper Island に数秒出して、コントロールセンターの一覧に残す。
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var latest: null
    readonly property var list: server.trackedNotifications.values

    function show(notification) {
        latest = notification;
        hideTimer.restart();
    }

    function clearAll() {
        for (const notification of list.slice())
            notification.dismiss();
    }

    // 「開く」動作があればそれを、なければ通知を消す
    function activate(notification) {
        const action = notification.actions.find(a => a.identifier === "default") || notification.actions[0];
        if (action)
            action.invoke();
        else
            notification.dismiss();
    }

    function iconFor(notification) {
        if (notification.image && notification.image.length > 0)
            return notification.image;
        if (notification.appIcon && notification.appIcon.length > 0)
            return notification.appIcon.startsWith("/") || notification.appIcon.startsWith("file:")
                ? notification.appIcon
                : Quickshell.iconPath(notification.appIcon, "dialog-information");
        return Quickshell.iconPath("dialog-information");
    }

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true;
            notification.closed.connect(() => {
                if (root.latest === notification)
                    root.latest = null;
            });
            // シェルを読み込み直したときに届き直した通知は、鳴らさずに一覧へ戻すだけ
            if (notification.lastGeneration)
                return;
            if (Session.doNotDisturb && notification.urgency !== NotificationUrgency.Critical)
                return;
            Sound.play("message-new-instant");
            root.show(notification);
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        onTriggered: root.latest = null
    }
}
