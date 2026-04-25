const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendScheduledMessages = functions
  .runWith({ maxInstances: 1 })
  .pubsub.schedule("every 1 minutes")
  .timeZone("Asia/Taipei")
  .onRun(async (context) => {
    const db = admin.firestore();
    const fcm = admin.messaging();
    const now = Date.now();

    try {
      const snapshot = await db
        .collection("scheduled_messages")
        .where("status", "==", "scheduled")
        .where("scheduledTime", "<=", now)
        .get();

      if (snapshot.empty) {
        console.log("沒有需要發送的訊息");
        return null;
      }

      const promises = snapshot.docs.map(async (doc) => {
        const data = doc.data();
        const receiverId = data.receiverId;
        const message = data.message;
        const senderName = data.senderName || "愛傳時";

        if (!receiverId || !message) return;

        try {
          const userDoc = await db
            .collection("users")
            .doc(receiverId)
            .get();

          if (!userDoc.exists) return;

          const fcmToken = userDoc.data().fcmToken;
          if (!fcmToken) return;

          if (data.autoPlay === true && data.voiceUrl) {
            await fcm.send({
              token: fcmToken,
              data: {
                autoPlay: 'true',
                voiceUrl: data.voiceUrl,
                messageType: 'voice',
                senderName: senderName,
              },
              android: {
                priority: "high",
              },
            });
          } else {
            await fcm.send({
              token: fcmToken,
              notification: {
                title: `來自 ${senderName} 的訊息`,
                body: message,
              },
              data: {
              autoPlay: 'false',
              voiceUrl: data.voiceUrl || '',
              messageType: data.messageType || 'text',
              senderName: senderName,
              },
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channelId: "scheduled_channel",
                },
              },
            });
          }

          await doc.ref.update({ status: "triggered" });
          console.log(`✅ 訊息已發送給 ${receiverId}`);
        } catch (err) {
          console.log(`❌ 發送失敗：${err}`);
        }
      });

      await Promise.all(promises);
      return null;
    } catch (err) {
      console.log(`❌ 查詢失敗：${err}`);
      return null;
    }
  });