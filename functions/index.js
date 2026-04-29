//v2
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

const paystackSecret = defineSecret("PAYSTACK_SECRET_KEY");

// ─── Helper: Send FCM notification to a user by uid ──────────────────────────
async function sendNotificationToUser({ uid, title, body, data = {} }) {
  try {
    const userDoc = await db.collection("getit_users").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      console.log(`No FCM token for user ${uid}`);
      return;
    }
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "getit_orders",
          priority: "max",
          defaultVibrateTimings: false,
          vibrateTimingsMillis: ["0", "500", "200", "500"],
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "interruption-level": "time-sensitive",
          },
        },
      },
    });
    console.log(`Notification sent to ${uid}: ${title}`);
  } catch (err) {
    console.error(`Failed to send notification to ${uid}:`, err.message);
  }
}

// ─── Send Notification (HTTP endpoint for Flutter to call) ───────────────────
exports.sendNotification = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  const { token, title, body, data } = req.body;

  if (!token || !title || !body) {
    return res.status(400).json({ error: "Missing token, title or body" });
  }

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "getit_orders",
          priority: "max",
          defaultVibrateTimings: false,
          vibrateTimingsMillis: ["0", "500", "200", "500"],
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "interruption-level": "time-sensitive",
          },
        },
      },
    });
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("sendNotification error:", err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ─── Paystack Webhook ─────────────────────────────────────────────────────────
exports.paystackWebhook = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const secret = paystackSecret.value();

    if (!secret) {
      console.error("PAYSTACK_SECRET_KEY is not set");
      return res.status(500).send("Server misconfiguration");
    }

    const hash = crypto
      .createHmac("sha512", secret)
      .update(JSON.stringify(req.body))
      .digest("hex");

    if (hash !== req.headers["x-paystack-signature"]) {
      console.error("Invalid Paystack signature");
      return res.status(401).send("Unauthorized");
    }

    const event = req.body;
    console.log("Paystack event:", event.event);

    if (event.event === "charge.success") {
      const reference = event.data.reference;
      const amount = event.data.amount;
      const status = event.data.status;

      if (status !== "success") return res.status(200).send("OK");

      try {
        const verifyRes = await axios.get(
          `https://api.paystack.co/transaction/verify/${reference}`,
          { headers: { Authorization: `Bearer ${secret}` } }
        );

        const verified = verifyRes.data;
        if (!verified.status || verified.data.status !== "success") {
          console.error("Payment verification failed", reference);
          return res.status(200).send("OK");
        }

        // Check getit_orders first (mobile/Android flow)
        const orderRef = db.collection("getit_orders").doc(reference);
        const orderDoc = await orderRef.get();

        if (orderDoc.exists) {
          const order = orderDoc.data();
          const expectedKobo = Math.round(order.total * 100);

          if (amount < expectedKobo) {
            await orderRef.update({
              paymentStatus: "amount_mismatch",
              webhookData: event.data,
            });
            return res.status(200).send("OK");
          }

          if (order.paymentStatus === "paid") {
            console.log("Order already paid:", reference);
            return res.status(200).send("OK");
          }

          await orderRef.update({
            paymentStatus: "paid",
            status: "pending",
            paystackReference: reference,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            webhookVerified: true,
            amountPaid: amount / 100,
          });

          // Notify each vendor in this order
          const shops = order.shops || {};
          for (const vendorId of Object.keys(shops)) {
            await sendNotificationToUser({
              uid: vendorId,
              title: "🛍️ New Order!",
              body: `${order.customerName || order.buyerName || "A customer"} placed an order • ₦${order.total?.toFixed(0) || ""}`,
              data: { type: "new_order", orderId: reference },
            });
          }

          console.log("Order confirmed via webhook:", reference);
        } else {
          // Check getit_pending_orders (web flow)
          const pendingRef = db.collection("getit_pending_orders").doc(reference);
          const pendingDoc = await pendingRef.get();

          if (pendingDoc.exists) {
            const orderData = pendingDoc.data();
            const expectedKobo = Math.round(orderData.total * 100);

            if (amount < expectedKobo) {
              console.error("Amount mismatch for pending order:", reference);
              return res.status(200).send("OK");
            }

            await db.collection("getit_orders").doc(reference).set({
              ...orderData,
              paymentStatus: "paid",
              status: "pending",
              paystackReference: reference,
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              webhookVerified: true,
              amountPaid: amount / 100,
            });

            await pendingRef.delete();

            // Notify each vendor for web orders too
            const shops = orderData.shops || {};
            for (const vendorId of Object.keys(shops)) {
              await sendNotificationToUser({
                uid: vendorId,
                title: "🛍️ New Order!",
                body: `${orderData.customerName || orderData.buyerName || "A customer"} placed an order • ₦${orderData.total?.toFixed(0) || ""}`,
                data: { type: "new_order", orderId: reference },
              });
            }

            console.log("Web order confirmed via webhook:", reference);
          } else {
            console.error("No order found for reference:", reference);
          }
        }
      } catch (err) {
        console.error("Webhook processing error:", err.response?.data || err.message);
      }
    }

    return res.status(200).send("OK");
  }
);

// ─── Initialize Payment ───────────────────────────────────────────────────────
exports.initializePayment = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { email, amount, reference, currency } = req.body;

    if (!email || !amount || !reference) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const secret = paystackSecret.value();

    if (!secret) {
      console.error("PAYSTACK_SECRET_KEY is not set");
      return res.status(500).json({ error: "Server misconfiguration" });
    }

    try {
      const response = await axios.post(
        "https://api.paystack.co/transaction/initialize",
        {
          email,
          amount: parseInt(amount),
          reference,
          currency: currency || "NGN",
          callback_url: "https://getit-db879.web.app/payment/callback",
        },
        {
          headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/json",
          },
        }
      );

      const authUrl = response.data.data.authorization_url;
      console.log("Payment initialized for reference:", reference);
      return res.status(200).json({ url: authUrl });
    } catch (err) {
      console.error("Initialize payment error:", err.response?.data || err.message);
      return res.status(500).json({
        error: "Failed to initialize payment",
        details: err.response?.data || err.message,
      });
    }
  }
);

// ─── Verify Payment ───────────────────────────────────────────────────────────
exports.verifyPayment = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { reference } = req.body;

    if (!reference) {
      return res.status(400).json({ error: "Missing reference" });
    }

    const secret = paystackSecret.value();

    try {
      const response = await axios.get(
        `https://api.paystack.co/transaction/verify/${reference}`,
        { headers: { Authorization: `Bearer ${secret}` } }
      );

      const data = response.data;

      if (data.status && data.data.status === "success") {
        console.log("Payment verified:", reference);
        return res.status(200).json({ paid: true });
      } else {
        console.log("Payment not successful:", reference);
        return res.status(200).json({ paid: false });
      }
    } catch (err) {
      console.error("Verify payment error:", err.response?.data || err.message);
      return res.status(200).json({ paid: false });
    }
  }
);

// ─── Auto-assign Picker ───────────────────────────────────────────────────────
// Triggered when vendor marks all items ready → Flutter sets status "ready_for_pickup"
// This function owns assignment — Flutter no longer calls _assignNearestPicker
exports.autoAssignPicker = onDocumentUpdated(
  "getit_orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    if (before.status === after.status) return null;
    if (after.status !== "ready_for_pickup") return null;
    if (after.pickerId) return null; // ✅ correct field — was after.riderId

    console.log("Finding picker for order:", orderId);

    try {
      const pickersSnap = await db
        .collection("getit_riders")
        .where("isAvailable", "==", true)
        .limit(10)
        .get();

      if (pickersSnap.empty) {
        console.log("No available pickers for order:", orderId);
        return null;
      }

      // Filter out riders that already have an active order
      const freePickers = pickersSnap.docs.filter((doc) => {
        const d = doc.data();
        return !d.currentOrderId || d.currentOrderId === "";
      });

      if (freePickers.length === 0) {
        console.log("All riders are busy for order:", orderId);
        return null;
      }

      // Pick the rider whose location was updated most recently
      freePickers.sort((a, b) => {
        const aT = a.data().locationUpdatedAt;
        const bT = b.data().locationUpdatedAt;
        if (!aT || !bT) return 0;
        return bT.toMillis() - aT.toMillis();
      });

      const picker = freePickers[0];
      const pickerData = picker.data();
      const pickerName = pickerData.name || pickerData.displayName || "Rider";

      await db.runTransaction(async (transaction) => {
        const freshOrder = await transaction.get(event.data.after.ref);
        const freshOrderData = freshOrder.data();

        // Abort if another invocation already assigned someone
        if (freshOrderData?.pickerId) {
          console.log("Picker already assigned — aborting transaction");
          return;
        }

        const riderRef = db.collection("getit_riders").doc(picker.id);
        const freshRider = await transaction.get(riderRef);
        const riderCurrentOrder = freshRider.data()?.currentOrderId;

        if (riderCurrentOrder && riderCurrentOrder !== "") {
          console.log("Rider already busy — aborting transaction");
          return;
        }

        // Mark every shop in the order as "assigned"
        const shops = freshOrderData?.shops || {};
        const shopUpdates = {};
        for (const shopId of Object.keys(shops)) {
          shopUpdates[`shops.${shopId}.status`] = "assigned"; // ✅ was "rider_assigned"
        }

        transaction.update(event.data.after.ref, {
          ...shopUpdates,
          pickerId: picker.id,   // ✅ was riderId
          pickerName,            // ✅ was riderName
          pickerEarning: 150,
          status: "assigned",    // ✅ was "rider_assigned"
          assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        transaction.update(riderRef, {
          isAvailable: false,
          currentOrderId: orderId,
        });
      });

      // Send FCM to the picker
      const vendorName =
        Object.values(after.shops || {})[0]?.shopName || "the vendor";
      const deliveryAddress = after.deliveryAddress || "customer location";

      await sendNotificationToUser({
        uid: picker.id,
        title: "🚴 New Delivery Assigned!",
        body: `Pickup from ${vendorName} → ${deliveryAddress}`,
        data: { type: "delivery_assigned", orderId },
      });

      console.log(`✅ Picker ${picker.id} assigned and notified for order ${orderId}`);
    } catch (err) {
      console.error("Auto-assign error:", err.message);
    }

    return null;
  }
);

// ─── Release Picker on Delivery + Credit Vendor Earnings ─────────────────────
exports.releasePickerOnDelivery = onDocumentUpdated(
  "getit_orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return null;
    if (after.status !== "delivered") return null;
    if (!after.pickerId) return null; // ✅ was after.riderId

    try {
      await db.collection("getit_riders").doc(after.pickerId).update({ // ✅ was after.riderId
        isAvailable: true,
        currentOrderId: "",
        totalDeliveries: admin.firestore.FieldValue.increment(1),
        totalEarnings: admin.firestore.FieldValue.increment(
          after.pickerEarning || 150
        ),
      });

      await event.data.after.ref.update({
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Credit each vendor's earnings
      const shops = after.shops || {};
      for (const [vendorId, shopData] of Object.entries(shops)) {
        const items = shopData.items || [];
        let vendorTotal = 0;
        for (const item of items) {
          vendorTotal += item.totalPrice || 0;
        }
        if (vendorTotal > 0) {
          try {
            await db.collection("getit_vendors").doc(vendorId).set(
              {
                totalEarnings: admin.firestore.FieldValue.increment(vendorTotal),
                withdrawnAmount: admin.firestore.FieldValue.increment(0),
              },
              { merge: true }
            );
            console.log(`Credited ₦${vendorTotal} to vendor ${vendorId}`);
          } catch (vendorErr) {
            console.error(`Failed to credit vendor ${vendorId}:`, vendorErr.message);
          }
        }
      }

      console.log(`✅ Picker ${after.pickerId} released after delivery of order ${event.params.orderId}`);
    } catch (err) {
      console.error("Release picker error:", err.message);
    }

    return null;
  }
);

// ─── Resolve Bank Account ─────────────────────────────────────────────────────
exports.resolveAccount = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { accountNumber, bankCode } = req.body;

    if (!accountNumber || !bankCode) {
      return res.status(400).json({ error: "Missing accountNumber or bankCode" });
    }

    try {
      const secret = paystackSecret.value();
      const response = await axios.get(
        `https://api.paystack.co/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`,
        { headers: { Authorization: `Bearer ${secret}` } }
      );

      const data = response.data;
      if (data.status) {
        return res.status(200).json({
          accountName: data.data.account_name,
          accountNumber: data.data.account_number,
        });
      }
      return res.status(400).json({ error: "Could not resolve account" });
    } catch (err) {
      console.error("Resolve account error:", err.response?.data || err.message);
      return res.status(400).json({ error: "Invalid account details" });
    }
  }
);

// ─── Withdraw Picker Earnings ─────────────────────────────────────────────────
exports.withdrawEarnings = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { pickerId, amount, accountNumber, bankCode, accountName } = req.body;

    if (!pickerId || !amount || !accountNumber || !bankCode) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (amount < 100) {
      return res.status(400).json({ error: "Minimum withdrawal is ₦100" });
    }

    try {
      const secret = paystackSecret.value();

      const riderDoc = await db.collection("getit_riders").doc(pickerId).get();
      if (!riderDoc.exists) {
        return res.status(404).json({ error: "Picker not found" });
      }

      const riderData = riderDoc.data();
      const totalEarnings = riderData.totalEarnings || 0;
      const withdrawnAmount = riderData.withdrawnAmount || 0;
      const availableBalance = totalEarnings - withdrawnAmount;

      if (amount > availableBalance) {
        return res.status(400).json({ error: "Insufficient balance" });
      }

      const recipientRes = await axios.post(
        "https://api.paystack.co/transferrecipient",
        {
          type: "nuban",
          name: accountName,
          account_number: accountNumber,
          bank_code: bankCode,
          currency: "NGN",
        },
        {
          headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/json",
          },
        }
      );

      const recipientCode = recipientRes.data.data.recipient_code;

      const transferRes = await axios.post(
        "https://api.paystack.co/transfer",
        {
          source: "balance",
          amount: Math.round(amount * 100),
          recipient: recipientCode,
          reason: `Get It picker earnings - ${pickerId.substring(0, 8)}`,
        },
        {
          headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/json",
          },
        }
      );

      const transfer = transferRes.data.data;
      console.log("Picker transfer initiated:", transfer.transfer_code);

      await db.collection("getit_riders").doc(pickerId).update({
        withdrawnAmount: admin.firestore.FieldValue.increment(amount),
        lastWithdrawal: {
          amount,
          bankName: riderData.bankAccount?.bankName || "",
          accountNumber,
          transferCode: transfer.transfer_code,
          status: transfer.status,
          date: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      return res.status(200).json({
        success: true,
        transferCode: transfer.transfer_code,
        status: transfer.status,
        amount,
      });
    } catch (err) {
      console.error("Picker withdraw error:", err.response?.data || err.message);
      return res.status(500).json({
        error: err.response?.data?.message || "Transfer failed. Try again.",
      });
    }
  }
);

// ─── Withdraw Vendor Earnings ─────────────────────────────────────────────────
exports.withdrawVendorEarnings = onRequest(
  { secrets: [paystackSecret] },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

    const { vendorId, amount, accountNumber, bankCode, accountName } = req.body;

    if (!vendorId || !amount || !accountNumber || !bankCode) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    if (amount < 100) {
      return res.status(400).json({ error: "Minimum withdrawal is ₦100" });
    }

    try {
      const secret = paystackSecret.value();

      const vendorDoc = await db.collection("getit_vendors").doc(vendorId).get();
      if (!vendorDoc.exists) {
        return res.status(404).json({ error: "Vendor not found" });
      }

      const vendorData = vendorDoc.data();
      const totalEarnings = vendorData.totalEarnings || 0;
      const withdrawnAmount = vendorData.withdrawnAmount || 0;
      const availableBalance = totalEarnings - withdrawnAmount;

      if (amount > availableBalance) {
        return res.status(400).json({ error: "Insufficient balance" });
      }

      const recipientRes = await axios.post(
        "https://api.paystack.co/transferrecipient",
        {
          type: "nuban",
          name: accountName,
          account_number: accountNumber,
          bank_code: bankCode,
          currency: "NGN",
        },
        {
          headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/json",
          },
        }
      );

      const recipientCode = recipientRes.data.data.recipient_code;

      const transferRes = await axios.post(
        "https://api.paystack.co/transfer",
        {
          source: "balance",
          amount: Math.round(amount * 100),
          recipient: recipientCode,
          reason: `Get It vendor earnings - ${vendorId.substring(0, 8)}`,
        },
        {
          headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/json",
          },
        }
      );

      const transfer = transferRes.data.data;
      console.log("Vendor transfer initiated:", transfer.transfer_code);

      await db.collection("getit_vendors").doc(vendorId).update({
        withdrawnAmount: admin.firestore.FieldValue.increment(amount),
        lastWithdrawal: {
          amount,
          bankName: vendorData.bankAccount?.bankName || "",
          accountNumber,
          transferCode: transfer.transfer_code,
          status: transfer.status,
          date: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      return res.status(200).json({
        success: true,
        transferCode: transfer.transfer_code,
        status: transfer.status,
        amount,
      });
    } catch (err) {
      console.error("Vendor withdraw error:", err.response?.data || err.message);
      return res.status(500).json({
        error: err.response?.data?.message || "Transfer failed. Try again.",
      });
    }
  }
);