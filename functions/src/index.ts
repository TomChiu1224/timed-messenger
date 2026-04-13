import * as functions from "firebase-functions";

export const helloWorld = functions.https.onRequest((request, response) => {
  functions.logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase! 愛傳時APP Functions is working! 🎉");
});

export const testFunction = functions.https.onRequest((request, response) => {
  const message = "愛傳時雲端函數測試成功！";
  response.json({
    success: true,
    message: message,
    timestamp: new Date().toISOString(),
  });
});


