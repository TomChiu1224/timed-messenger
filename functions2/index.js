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

  exports.deleteUserAccount = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "必須登入才能刪除帳號"
      );
    }

    const uid = context.auth.uid;
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();

    console.log(`🗑️ 開始刪除使用者 ${uid} 的所有資料`);

    try {
      console.log(`[1/8] 刪除 users/${uid}`);
      await db.collection("users").doc(uid).delete();

      console.log(`[2/8] 刪除 friends/${uid}`);
      await db.collection("friends").doc(uid).delete();

      console.log(`[3/8] 從其他人的好友列表中移除 ${uid}`);
      const allFriendsSnapshot = await db.collection("friends").get();
      let removedFromOthers = 0;
      const friendBatchPromises = [];
      let currentBatch = db.batch();
      let currentBatchCount = 0;

      for (const friendDoc of allFriendsSnapshot.docs) {
        const friendData = friendDoc.data();
        if (friendData && friendData[uid] !== undefined) {
          currentBatch.update(friendDoc.ref, {
            [uid]: admin.firestore.FieldValue.delete(),
          });
          currentBatchCount++;
          removedFromOthers++;
          if (currentBatchCount >= 400) {
            friendBatchPromises.push(currentBatch.commit());
            currentBatch = db.batch();
            currentBatchCount = 0;
          }
        }
      }
      if (currentBatchCount > 0) {
        friendBatchPromises.push(currentBatch.commit());
      }
      await Promise.all(friendBatchPromises);
      console.log(`   從 ${removedFromOthers} 個好友列表中移除`);

      console.log(`[4/8] 刪除自己寄出的訊息`);
      const sentSnapshot = await db
        .collection("scheduled_messages")
        .where("senderId", "==", uid)
        .get();
      let sentBatch = db.batch();
      let sentCount = 0;
      const sentBatchPromises = [];
      for (const doc of sentSnapshot.docs) {
        sentBatch.delete(doc.ref);
        sentCount++;
        if (sentCount % 400 === 0) {
          sentBatchPromises.push(sentBatch.commit());
          sentBatch = db.batch();
        }
      }
      if (sentCount % 400 !== 0) {
        sentBatchPromises.push(sentBatch.commit());
      }
      await Promise.all(sentBatchPromises);
      console.log(`   已刪除 ${sentSnapshot.size} 則寄出訊息`);

      console.log(`[5/8] 刪除自己收到的訊息`);
      const receivedSnapshot = await db
        .collection("scheduled_messages")
        .where("receiverId", "==", uid)
        .get();
      let recvBatch = db.batch();
      let recvCount = 0;
      const recvBatchPromises = [];
      for (const doc of receivedSnapshot.docs) {
        recvBatch.delete(doc.ref);
        recvCount++;
        if (recvCount % 400 === 0) {
          recvBatchPromises.push(recvBatch.commit());
          recvBatch = db.batch();
        }
      }
      if (recvCount % 400 !== 0) {
        recvBatchPromises.push(recvBatch.commit());
      }
      await Promise.all(recvBatchPromises);
      console.log(`   已刪除 ${receivedSnapshot.size} 則收到訊息`);

      console.log(`[6/8] 刪除 special_accounts/${uid}`);
      try {
        await db.collection("special_accounts").doc(uid).delete();
      } catch (e) {
        console.log(`   special_accounts 刪除略過：${e.message}`);
      }

      console.log(`[7/8] 刪除 Storage 上的所有檔案`);
      const userPrefixes = [
        `message_images/${uid}/`,
        `voice_messages/voice_${uid}_`,
      ];
      let totalDeletedFiles = 0;
      for (const prefix of userPrefixes) {
        try {
          const [files] = await bucket.getFiles({ prefix: prefix });
          if (files.length > 0) {
            await Promise.all(files.map((file) => file.delete()));
            totalDeletedFiles += files.length;
            console.log(`   刪除 ${prefix}：${files.length} 個檔案`);
          } else {
            console.log(`   ${prefix}：沒有檔案需要刪除`);
          }
        } catch (e) {
          console.log(`   ${prefix} 刪除失敗：${e.message}`);
        }
      }
      console.log(`   Storage 總共刪除 ${totalDeletedFiles} 個檔案`);

      console.log(`[8/8] 刪除 Auth 帳號 ${uid}`);
      await admin.auth().deleteUser(uid);

      console.log(`✅ 使用者 ${uid} 的所有資料已徹底刪除`);
      return { success: true, message: "帳號已成功刪除" };
    } catch (err) {
      console.log(`❌ 刪除過程發生錯誤：${err}`);
      throw new functions.https.HttpsError(
        "internal",
        `刪除帳號失敗：${err.message}`
      );
    }
  });