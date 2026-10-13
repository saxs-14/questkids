importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCMH4vPHX9ohTaK6HQSB4sCUE10C6oPNCY",
  appId: "1:882077922348:web:130f4b96e9d2122fa5cd89",
  messagingSenderId: "882077922348",
  projectId: "questkids-mobile",
  authDomain: "questkids-mobile.firebaseapp.com",
  storageBucket: "questkids-mobile.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const title = payload.data?.title || "QuestKids";
  const options = {
    body: payload.data?.body || "",
    icon: "/icons/Icon-192.png",
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
