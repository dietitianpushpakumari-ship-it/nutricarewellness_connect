// functions/index.js

const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

admin.initializeApp();

exports.adminSetClientPassword = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
      const clientId = data.clientId;
      const mobileNumber = data.mobileNumber;
      const password = data.password;
      const updateData = data.updateData;

      // Email format: [mobileNumber]@nutricarewellness.in
      const authEmail = `${mobileNumber}@nutricarewellness.in`;

      if (!clientId || !mobileNumber || !password || password.length < 6) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Client ID, mobile number, and password are required.",
        );
      }

      try {
      // 1. Check if the user already exists using the Firestore D
        let userRecord;
        try {
          userRecord = await admin.auth().getUser(clientId);
        } catch (e) {
          if (e.code !== "auth/user-not-found") {
            throw e;
          }
        // If user-not-found, userRecord remains undefined, proceed to CREATE.
        }

        if (updateData && Object.keys(updateData).length > 0) {
          updateData.updatedAt = admin.firestore.FieldValue
              .serverTimestamp();

          await admin.firestore().collection("clients").doc(clientId)
              .update(updateData);
        }

        if (userRecord) {
        // 2. USER EXISTS (Duplicate registration attempt): Update the password
          await admin.auth().updateUser(clientId, {
            password: password,
            emailVerified: true, // Re-verify credential
          });
          return {success: true, message: `Password successfully updated`};
        } else {
        // 3. USER DOES NOT EXIST: Create the new credential
          await admin.auth().createUser({
            uid: clientId, // Use the unique Firestore Document ID
            email: authEmail, // Use the mobile number for the unique email
            password: password,
            displayName: mobileNumber,
            emailVerified: true,
          });
          return {success: true, message: `Credential successfully`};
        }
      } catch (error) {
        console.error("CRITICAL AUTH ERROR:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Authentication process failed on the server. Please check logs.",
            error.message,
        );
      }
    });

// functions/index.js (Add this new function)

// ... (omitted existing imports and admin.initializeApp()) ...

/**
 * Securly verifies a client's identity using
 * Uses the Admin SDK to bypass security rules for a safe read operation.
 */
exports.verifyClientData = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
      const {patientId, mobile} = data;

      if (!patientId || !mobile) {
        throw new functions.https.HttpsError("invalid-argument', 'invalid'.");
      }

      try {
        const db = admin.firestore();

        // 🎯 Admin SDK query bypasses Firestore Security Rules
        const snapshot = await db.collection("clients")
            .where("patientId", "==", patientId)
            .where("mobile", "==", mobile)
            .limit(1)
            .get();

        if (snapshot.empty) {
          return {found: false, message: "No matching client record found."};
        }

        const doc = snapshot.docs[0];
        const clientData = doc.data();

        // Check if credentials are already set (prevents re-registration)
        if (clientData.hasPasswordSet) {
          throw new functions
              .https
              .HttpsError("failed-precondition", "Account exists.");
        }

        // Return only the essential, verified infor
        return {
          found: true,
          client: {
            id: doc.id,
            hasPasswordSet: clientData.hasPasswordSet,
            status: clientData.status,
            isArchived: clientData.isArchived,
            isSoftDeleted: clientData.isSoftDeleted,
          },
        };
      } catch (error) {
      // Re-throw specific Auth errors or a generic internal error
        if (error.code === "failed-precondition") {
          throw error;
        }
        console.error("Error verifying client data securely:", error);
        throw new functions.https.HttpsError("internal", "Server error");
      }
    });


/**
     * Generates a temporary code and sends it via Push Notification (preferred)
     * or returns a flag if SMS is required.
     */
exports.generateAndSendOtp = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
      const {mobileNumber, fcmToken} = data;
      const db = admin.firestore();

      if (!mobileNumber) {
        throw new functions.https.HttpsError("invalid-argument",
            "Mobile number is required.");
      }

      // 1. Generate a 6-digit OTP
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const verificationId = admin.firestore().collection("temp_otp").doc().id;

      // 2. Store OTP temporarily in Firestore with a 5-minute expiry (TTL)
      await db.collection("temp_otp").doc(verificationId).set({
        code: otpCode,
        mobile: mobileNumber,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 5 * 60000), // Expires in 5 minutes
      });

      // 3. If FCM Token is provided, send via PUSH notification
      if (fcmToken) {
        try {
          const message = {
            token: fcmToken,
            notification: {
              title: "NutriCare OTP Code",
              body: `Your verification code is: ${otpCode}.
                  It expires in 5 minutes.`,
            },
            data: {
              otp_code: otpCode,
              session_id: verificationId,
            },
          };

          await admin.messaging().send(message);

          return {status: "SENT_VIA_PUSH", verificationId: verificationId};
        } catch (error) {
          console.error("FCM PUSH failed, falling back to SMS.", error);
          // Fall through to SMS required flag
        }
      }

      // 4. Fallback: Return SMS_REQUIRED flag if PUSH failed
      return {status: "SMS_REQUIRED"};
    });

// --- Function 2: Generate and Send OTP (PUSH/SMS Fallback) ---

/**
 * Generates OTP, stores it in temp_otp collection, and attempts to send
 * Falls back to SMS_REQUIRED PUSH fails.
 */
exports.generateAndSendOtp = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
      const {mobileNumber, fcmToken} = data;
      const db = admin.firestore();

      if (!mobileNumber) {
        throw new functions.https.HttpsError("invalid-argument",
            "Mobile number is required.",
        );
      }

      // 1. Generate a 6-digit OTP and unique session ID
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const verificationId = db.collection("temp_otp").doc().id;

      // 2. Store OTP temporarily in Firestore (for 5 minutes)
      await db.collection("temp_otp").doc(verificationId).set({
        code: otpCode,
        mobile: mobileNumber,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 5 * 60000), // Expires in 5 minutes
      });

      // 3. Attempt to send via PUSH notification if token is available
      if (fcmToken) {
        try {
          const message = {
            token: fcmToken,
            notification: {
              title: "NutriCare OTP Code",
              body: `Your verification code is: ${otpCode}.
               It expires in 5 minutes.`,
            },
            data: {
              otp_code: otpCode,
              session_id: verificationId,
            },
          };

          await admin.messaging().send(message);

          return {status: "SENT_VIA_PUSH", verificationId: verificationId};
        } catch (error) {
          console.error("FCM PUSH failed, falling back to SMS.", error);
          // Fall through to SMS required flag
        }
      }

      // 4. Fallback: Return SMS_REQUIRED flag
      return {status: "SMS_REQUIRED"};
    });

// 🎯 NOTE: You will need a third function (verifyOtpCode) to check the OTP
// against the 'temp_otp' collection for the PUSH flow. This is currently
// handled by the native Firebase Auth SMS verification.


exports.fetchClientByLoginId = functions
    .region("asia-south1").https.onCall(async (data, context) => {
      const loginId = data.loginId;

      let clientSnapshot = await admin.firestore().collection("clients")
          .where("loginId", "==", loginId)
          .limit(1)
          .get();

      if (clientSnapshot.empty) {
        // Fallback to mobile number if loginId didn't match
        clientSnapshot = await admin.firestore().collection("clients")
            .where("mobile", "==", loginId)
            .limit(1)
            .get();
      }

      if (clientSnapshot.empty) {
        return {}; // Return empty map if not found
      }

      const doc = clientSnapshot.docs[0];
      const clientData = doc.data();

      return {
        ...clientData,
        id: doc.id, // Ensure the document ID is included
      };
    });
