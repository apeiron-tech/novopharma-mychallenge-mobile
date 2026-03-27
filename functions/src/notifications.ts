/* eslint-disable indent */
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Don't initialize here - it's initialized in index.ts

/**
 * Sends a notification to all users when a new training is created
 */
export const onNewTrainingCreated = functions.firestore
    .document("blogPosts/{postId}")
    .onCreate(async (snap, context) => {
        const post = snap.data();
        const postId = context.params.postId;

        // Check notification toggle
        if (post?.notification === false) {
            console.log(`Post ${postId} has notification disabled, skipping`);
            return {success: true, skipped: true};
        }

        // Check if post is for testing
        const postTitle = post?.title;
        const isTestDev = typeof postTitle === "string" &&
            postTitle.toLowerCase().includes("test dev");


        const isFormation = post?.type === "formation";
        const notifTitle = isFormation ?
            "Nouvelle formation disponible !" :
            "Nouvelle actualité disponible !";
        const notifBodyDefault = isFormation ?
            "Une nouvelle formation vient d'être publiée" :
            "Une nouvelle actualité vient d'être publiée";
        const notifType = isFormation ? "newTraining" : "newActualite";

        console.log(`New post created: ${postId}, type: ${post?.type}`);

        try {
            // Get all users
            const usersSnapshot = await admin
                .firestore()
                .collection("users")
                .get();

            const batch = admin.firestore().batch();
            const notifications: Array<{
                token: string;
                notification: admin.messaging.Notification;
                data: { [key: string]: string };
            }> = [];

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;

                // Filter users if test dev
                if (isTestDev && (!userData.email ||
                    !userData.email.includes("testdev"))) {
                    continue; // Skip non-test users for test dev posts
                }


                // Create notification document
                const notificationRef = admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                batch.set(notificationRef, {
                    userId: userId,
                    title: notifTitle,
                    body: post?.title || notifBodyDefault,
                    type: notifType,
                    resourceId: postId,
                    imageUrl: post?.imageUrl || null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Prepare FCM message if user has a token
                const userTokens = userData.fcmTokens ||
                    (fcmToken ? [fcmToken] : []);
                userTokens.forEach((token: string) => {
                    notifications.push({
                        token: token,
                        notification: {
                            title: notifTitle,
                            body: post?.title || notifBodyDefault,
                        },
                        data: {
                            type: notifType,
                            resourceId: postId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    });
                });
            }

            // Commit all notification documents
            await batch.commit();
            console.log(
                `Created ${usersSnapshot.docs.length} notification documents`
            );

            // Send FCM messages
            if (notifications.length > 0) {
                const messages = notifications.map((notif) => ({
                    token: notif.token,
                    notification: notif.notification,
                    data: notif.data,
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                }));

                const response = await admin.messaging().sendEach(messages);
                console.log(
                    `Sent ${response.successCount} FCM notifications, ` +
                    `${response.failureCount} failures`
                );
            }

            return {success: true};
        } catch (error) {
            console.error("Error sending training notifications:", error);
            return {success: false, error};
        }
    });

/**
 * Sends a notification to filtered users when a new badge is created.
 * Filtering is based on badge.visibilityCriteria.clientCategories:
 *  - "Pharmacie" or "" => only users in Pharmacie pharmacies
 *  - "Para-Pharmacie"  => only users in Para-Pharmacie pharmacies
 */
export const onNewBadgeCreated = functions.firestore
    .document("badges/{badgeId}")
    .onCreate(async (snap, context) => {
        const badge = snap.data();
        const badgeId = context.params.badgeId;

        // Check notification toggle
        if (badge?.notification === false) {
            console.log(`Badge ${badgeId} has notification disabled, skipping`);
            return {success: true, skipped: true};
        }

        // Check if badge is for testing
        const badgeTitle = badge?.name;
        const isTestDev = typeof badgeTitle === "string" &&
            badgeTitle.toLowerCase().includes("test dev");


        console.log(`New badge created: ${badgeId}`);

        try {
            // Build map: pharmacyId => clientCategory
            const pharmaciesSnapshot = await admin
                .firestore()
                .collection("pharmacies")
                .get();
            const pharmacyCategoryMap = new Map<string, string>();
            pharmaciesSnapshot.docs.forEach((doc) => {
                pharmacyCategoryMap.set(doc.id, doc.data().clientCategory);
            });

            // Get all users
            const usersSnapshot = await admin
                .firestore()
                .collection("users")
                .get();

            // Determine which client categories this badge targets
            const visibilityClientCats =
                badge.visibilityCriteria?.clientCategories || [];
            let allowedCategories: string[] = visibilityClientCats;
            if (
                !Array.isArray(allowedCategories) ||
                allowedCategories.length === 0
            ) {
                allowedCategories = ["Pharmacie"];
            } else {
                allowedCategories = allowedCategories.map((c: string) =>
                    c === "" || c === "Pharmacie" ? "Pharmacie" : c
                );
            }

            const batch = admin.firestore().batch();
            let batchCount = 0;
            const notifications: Array<{
                token: string;
                notification: admin.messaging.Notification;
                data: { [key: string]: string };
            }> = [];

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;

                // Filter users if test dev
                if (isTestDev && (!userData.email ||
                    !userData.email.includes("testdev"))) {
                    continue; // Skip non-test users for test dev badges
                }


                const userPharmacyId = userData.pharmacyId;
                const userClientCategory = userPharmacyId ?
                    (pharmacyCategoryMap.get(userPharmacyId) || "Pharmacie") :
                    "Pharmacie";

                if (!allowedCategories.includes(userClientCategory)) {
                    continue; // Skip user not in allowed client categories
                }

                // Create notification document
                const notificationRef = admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                batch.set(notificationRef, {
                    userId: userId,
                    title: "Nouveau badge disponible !",
                    body: badge.name || "Un nouveau badge vient d'être lancé",
                    type: "newBadge",
                    resourceId: badgeId,
                    imageUrl: badge.imageUrl || null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                batchCount++;

                // Prepare FCM message if user has a token
                const userTokens = userData.fcmTokens ||
                    (fcmToken ? [fcmToken] : []);
                userTokens.forEach((token: string) => {
                    notifications.push({
                        token: token,
                        notification: {
                            title: "Nouveau badge disponible !",
                            body:
                                badge.name ||
                                "Un nouveau badge vient d'être lancé",
                        },
                        data: {
                            type: "newBadge",
                            resourceId: badgeId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    });
                });
            }

            // Commit all notification documents
            if (batchCount > 0) {
                await batch.commit();
            }
            console.log(`Created ${batchCount} notification documents`);

            // Send FCM messages
            if (notifications.length > 0) {
                const messages = notifications.map((notif) => ({
                    token: notif.token,
                    notification: notif.notification,
                    data: notif.data,
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                }));

                const response = await admin.messaging().sendEach(messages);
                console.log(
                    `Sent ${response.successCount} FCM notifications, ` +
                    `${response.failureCount} failures`
                );
            }

            return {success: true};
        } catch (error) {
            console.error("Error sending badge notifications:", error);
            return {success: false, error};
        }
    });

/**
 * Sends a notification to a user when they earn a badge
 */
export const onUserBadgeAwarded = functions.firestore
    .document("users/{userId}/userBadges/{badgeId}")
    .onCreate(async (snap, context) => {
        const userId = context.params.userId as string;
        const badgeId = context.params.badgeId as string;

        console.log(`User ${userId} earned badge ${badgeId}`);

        try {
            // Get badge details
            const badgeDoc = await admin
                .firestore()
                .collection("badges")
                .doc(badgeId)
                .get();
            const badge = badgeDoc.data();

            // Get user FCM token
            const userDoc = await admin
                .firestore()
                .collection("users")
                .doc(userId)
                .get();
            const userData = userDoc.data();
            const fcmTokens: string[] = userData?.fcmTokens ||
                (userData?.fcmToken ? [userData?.fcmToken] : []);

            // Create notification document
            const notificationRef = admin
                .firestore()
                .collection("users")
                .doc(userId)
                .collection("notifications")
                .doc();

            const badgeName = badge?.name || "Nouveau badge";
            const notificationBody =
                `Vous avez obtenu le badge "${badgeName}"`;

            await notificationRef.set({
                userId: userId,
                title: "Félicitations ! 🎉",
                body: notificationBody,
                type: "achievement",
                resourceId: badgeId,
                imageUrl: badge?.imageUrl || null,
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Send FCM notifications to all user tokens
            if (fcmTokens.length > 0) {
                const messages = fcmTokens.map((token) => ({
                    token: token,
                    notification: {
                        title: "Félicitations ! 🎉",
                        body: notificationBody,
                    },
                    data: {
                        type: "achievement",
                        resourceId: badgeId,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                }));
                await admin.messaging().sendEach(messages);
            }

            // Notify admins
            const adminsSnapshot = await admin
                .firestore()
                .collection("users")
                .where("role", "==", "admin")
                .get();

            if (!adminsSnapshot.empty) {
                const batch = admin.firestore().batch();
                const userName = userData?.name ||
                    userData?.email ||
                    "Un utilisateur";
                const adminTitle = "Nouveau badge obtenu !";
                const adminBody =
                    `${userName} a obtenu le badge "${badgeName}"`;

                const adminNotifications: Array<{
                    token: string;
                    notification: admin.messaging.Notification;
                    data: { [key: string]: string };
                }> = [];

                adminsSnapshot.docs.forEach((adminDoc) => {
                    const adminId = adminDoc.id;
                    const adminData = adminDoc.data();

                    const adminNotifRef = admin
                        .firestore()
                        .collection("users")
                        .doc(adminId)
                        .collection("notifications")
                        .doc();

                    batch.set(adminNotifRef, {
                        userId: adminId,
                        title: adminTitle,
                        body: adminBody,
                        type: "achievement",
                        resourceId: badgeId,
                        imageUrl: badge?.imageUrl || null,
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    const adminTokens: string[] = adminData.fcmTokens ||
                        (adminData.fcmToken ? [adminData.fcmToken] : []);
                    adminTokens.forEach((token) => {
                        adminNotifications.push({
                            token: token,
                            notification: {
                                title: adminTitle,
                                body: adminBody,
                            },
                            data: {
                                type: "achievement",
                                resourceId: badgeId,
                                click_action: "FLUTTER_NOTIFICATION_CLICK",
                            },
                        });
                    });
                });

                await batch.commit();

                if (adminNotifications.length > 0) {
                    const messages = adminNotifications.map((notif) => ({
                        token: notif.token,
                        notification: notif.notification,
                        data: notif.data,
                        android: {
                            priority: "high" as const,
                            notification: {
                                channelId: "novopharma_channel",
                                sound: "default",
                            },
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: "default",
                                    badge: 1,
                                },
                            },
                        },
                    }));
                    await admin.messaging().sendEach(messages);
                }
            }

            return {success: true};
        } catch (error) {
            console.error(
                "Error sending badge achievement notification:",
                error
            );
            return {success: false, error};
        }
    });

/**
 * Sends a notification to filtered users when a new goal is created.
 * Filtering is based on goal.criteria.clientCategories:
 *  - "Pharmacie" or "" => only users in Pharmacie pharmacies
 *  - "Para-Pharmacie"  => only users in Para-Pharmacie pharmacies
 */
export const onNewGoalCreated = functions.firestore
    .document("goals/{goalId}")
    .onCreate(async (snap, context) => {
        const goal = snap.data();
        const goalId = context.params.goalId;

        // Check notification toggle
        if (goal?.notification === false) {
            console.log(`Goal ${goalId} has notification disabled, skipping`);
            return {success: true, skipped: true};
        }

        // Check if goal is for testing
        const goalTitle = goal?.title;
        const isTestDev = typeof goalTitle === "string" &&
            goalTitle.toLowerCase().includes("test dev");


        console.log(`New goal created: ${goalId}`);

        try {
            // Build map: pharmacyId => clientCategory
            const pharmaciesSnapshot = await admin
                .firestore()
                .collection("pharmacies")
                .get();
            const pharmacyCategoryMap = new Map<string, string>();
            pharmaciesSnapshot.docs.forEach((doc) => {
                pharmacyCategoryMap.set(doc.id, doc.data().clientCategory);
            });

            // Get all users
            const usersSnapshot = await admin
                .firestore()
                .collection("users")
                .get();

            // Determine which client categories this goal targets
            const criteriaClientCats =
                goal.criteria?.clientCategories || [];
            let allowedCategories: string[] = criteriaClientCats;
            if (
                !Array.isArray(allowedCategories) ||
                allowedCategories.length === 0
            ) {
                allowedCategories = ["Pharmacie"];
            } else {
                allowedCategories = allowedCategories.map((c: string) =>
                    c === "" || c === "Pharmacie" ? "Pharmacie" : c
                );
            }

            const batch = admin.firestore().batch();
            let batchCount = 0;
            const notifications: Array<{
                token: string;
                notification: admin.messaging.Notification;
                data: { [key: string]: string };
            }> = [];

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;

                // Filter users if test dev
                if (isTestDev && (!userData.email ||
                    !userData.email.includes("testdev"))) {
                    continue; // Skip non-test users for test dev goals
                }


                const userPharmacyId = userData.pharmacyId;
                const userClientCategory = userPharmacyId ?
                    (pharmacyCategoryMap.get(userPharmacyId) || "Pharmacie") :
                    "Pharmacie";

                if (!allowedCategories.includes(userClientCategory)) {
                    continue; // Skip user not in allowed client categories
                }

                // Create notification document
                const notificationRef = admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                batch.set(notificationRef, {
                    userId: userId,
                    title: "Nouvel objectif disponible !",
                    body: goal.description ||
                        "Un nouvel objectif a été ajouté",
                    type: "newGoal",
                    resourceId: goalId,
                    imageUrl: null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                batchCount++;

                // Prepare FCM message if user has a token
                const userTokens: string[] = userData.fcmTokens ||
                    (fcmToken ? [fcmToken] : []);
                userTokens.forEach((token) => {
                    notifications.push({
                        token: token,
                        notification: {
                            title: "Nouvel objectif disponible !",
                            body: goal.description ||
                                "Un nouvel objectif a été ajouté",
                        },
                        data: {
                            type: "newGoal",
                            resourceId: goalId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    });
                });
            }

            // Commit all notification documents
            if (batchCount > 0) {
                await batch.commit();
            }
            console.log(
                `Created ${batchCount} notification documents for goals`
            );

            // Send FCM messages
            if (notifications.length > 0) {
                const messages = notifications.map((notif) => ({
                    token: notif.token,
                    notification: notif.notification,
                    data: notif.data,
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                }));

                const response = await admin.messaging().sendEach(messages);
                console.log(
                    `Sent ${response.successCount} FCM notifications, ` +
                    `${response.failureCount} failures`
                );
            }

            return {success: true};
        } catch (error) {
            console.error("Error sending goal notifications:", error);
            return {success: false, error};
        }
    });

/**
 * Sends a notification to a user when they complete a goal
 */
export const onUserGoalCompleted = functions.firestore
    .document("users/{userId}/userGoalProgress/{goalId}")
    .onWrite(async (change, context) => {
        const userId = context.params.userId as string;
        const goalId = context.params.goalId as string;

        const beforeDoc = change.before.data();
        const afterDoc = change.after.data();

        // Skip if document was deleted
        if (!afterDoc) {
            return {success: true, skipped: true};
        }

        // Check if status changed to "completed"
        const wasCompleted = beforeDoc?.status === "completed";
        const isCompleted = afterDoc?.status === "completed";

        if (!wasCompleted && isCompleted) {
            console.log(`User ${userId} completed goal ${goalId}`);

            try {
                // Get goal details
                const goalDoc = await admin
                    .firestore()
                    .collection("goals")
                    .doc(goalId)
                    .get();
                const goal = goalDoc.data();

                // Get user FCM token
                const userDoc = await admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .get();
                const userData = userDoc.data();
                const fcmTokens: string[] = userData?.fcmTokens ||
                    (userData?.fcmToken ? [userData?.fcmToken] : []);

                // Create notification document
                const notificationRef = admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                const goalTitle = goal?.title || "Objectif";
                const notificationBody =
                    "Félicitations ! Vous avez atteint l'objectif " +
                    `"${goalTitle}"`;

                await notificationRef.set({
                    userId: userId,
                    title: "Objectif atteint ! 🎉",
                    body: notificationBody,
                    type: "goalCompleted",
                    resourceId: goalId,
                    imageUrl: goal?.imageUrl || null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Send FCM notification to all devices
                if (fcmTokens.length > 0) {
                    const messages = fcmTokens.map((token) => ({
                        token: token,
                        notification: {
                            title: "Objectif atteint ! 🎉",
                            body: notificationBody,
                        },
                        data: {
                            type: "goalCompleted",
                            resourceId: goalId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                        android: {
                            priority: "high" as const,
                            notification: {
                                channelId: "novopharma_channel",
                                sound: "default",
                            },
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: "default",
                                    badge: 1,
                                },
                            },
                        },
                    }));
                    await admin.messaging().sendEach(messages);
                }

                // Notify admins
                const adminsSnapshot = await admin
                    .firestore()
                    .collection("users")
                    .where("role", "==", "admin")
                    .get();

                if (!adminsSnapshot.empty) {
                    const batch = admin.firestore().batch();
                    const userName = userData?.name ||
                        userData?.email ||
                        "Un utilisateur";
                    const adminTitle = "Objectif atteint !";
                    const adminBody =
                        `${userName} a atteint l'objectif "${goalTitle}"`;

                    const adminNotifications: Array<{
                        token: string;
                        notification: admin.messaging.Notification;
                        data: { [key: string]: string };
                    }> = [];

                    adminsSnapshot.docs.forEach((adminDoc) => {
                        const adminId = adminDoc.id;
                        const adminData = adminDoc.data();

                        const adminNotifRef = admin
                            .firestore()
                            .collection("users")
                            .doc(adminId)
                            .collection("notifications")
                            .doc();

                        batch.set(adminNotifRef, {
                            userId: adminId,
                            title: adminTitle,
                            body: adminBody,
                            type: "goalCompleted",
                            resourceId: goalId,
                            imageUrl: goal?.imageUrl || null,
                            isRead: false,
                            createdAt: admin.firestore.FieldValue
                                .serverTimestamp(),
                        });

                        const adminTokens: string[] = adminData.fcmTokens ||
                            (adminData.fcmToken ? [adminData.fcmToken] : []);
                        adminTokens.forEach((token) => {
                            adminNotifications.push({
                                token: token,
                                notification: {
                                    title: adminTitle,
                                    body: adminBody,
                                },
                                data: {
                                    type: "goalCompleted",
                                    resourceId: goalId,
                                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                                },
                            });
                        });
                    });

                    await batch.commit();

                    if (adminNotifications.length > 0) {
                        const messages = adminNotifications.map((notif) => ({
                            token: notif.token,
                            notification: notif.notification,
                            data: notif.data,
                            android: {
                                priority: "high" as const,
                                notification: {
                                    channelId: "novopharma_channel",
                                    sound: "default",
                                },
                            },
                            apns: {
                                payload: {
                                    aps: {
                                        sound: "default",
                                        badge: 1,
                                    },
                                },
                            },
                        }));
                        await admin.messaging().sendEach(messages);
                    }
                }

                return {success: true};
            } catch (error) {
                console.error(
                    "Error sending goal completion notification:",
                    error
                );
                return {success: false, error};
            }
        }

        return {success: true, skipped: true};
    });

/**
 * Scheduled function to send reminder notifications
 * Runs every day at 10:00 AM Europe/Paris
 */
export const sendReminderNotifications = functions.pubsub
    .schedule("0 10 * * *")
    .timeZone("Europe/Paris")
    .onRun(async () => {
        const now = new Date();
        now.setHours(0, 0, 0, 0); // start of today
        const adminDb = admin.firestore();
        const usersSnapshot = await adminDb.collection("users").get();
        const msPerDay = 1000 * 60 * 60 * 24;

        // Function to check if reminder should be sent today
        const shouldSendReminder = (
            endDateStr: string | admin.firestore.Timestamp | undefined,
            reminderDateNum = 3
        ) => {
            if (!endDateStr) return false;
            let endDate: Date;
            if (typeof endDateStr === "string") {
                endDate = new Date(endDateStr);
            } else if (typeof (endDateStr as
                { toDate: () => Date }).toDate === "function") {
                endDate = (endDateStr as { toDate: () => Date }).toDate();
            } else {
                return false;
            }
            endDate.setHours(0, 0, 0, 0);
            const diffDays = Math.round(
                (endDate.getTime() - now.getTime()) / msPerDay
            );
            return diffDays === reminderDateNum;
        };

        // Helper to notify relevant users for an item
        const sendRemindersToUsers = async (
            itemType: string, itemId: string, title: string,
            body: string, isTestDev: boolean, allowedCategories: string[] | null
        ) => {
            const batch = adminDb.batch();
            let batchCount = 0;
            const notifications: Array<{
                token: string;
                notification: admin.messaging.Notification;
                data: { [key: string]: string }
            }> = [];

            const pharmacyCategoryMap = new Map<string, string>();
            if (allowedCategories) {
                const pharmaciesSnapshot = await adminDb
                    .collection("pharmacies").get();
                pharmaciesSnapshot.docs.forEach((doc) => {
                    pharmacyCategoryMap.set(doc.id, doc.data().clientCategory);
                });
            }

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;

                if (isTestDev &&
                    (!userData.email || !userData.email.includes("testdev"))) {
                    continue;
                }

                if (allowedCategories) {
                    const userPharmacyId = userData.pharmacyId;
                    const userClientCategory = userPharmacyId ?
                        (pharmacyCategoryMap.get(userPharmacyId) ||
                            "Pharmacie") :
                        "Pharmacie";
                    if (!allowedCategories.includes(userClientCategory)) {
                        continue;
                    }
                }

                const notifRef = adminDb.collection("users").doc(userId)
                    .collection("notifications").doc();
                batch.set(notifRef, {
                    userId, title, body, type: itemType, resourceId: itemId,
                    imageUrl: null, isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                batchCount++;
                const userTokens: string[] = userData.fcmTokens ||
                    (fcmToken ? [fcmToken] : []);
                userTokens.forEach((token) => {
                    notifications.push({
                        token: token,
                        notification: {title, body},
                        data: {
                            type: itemType, resourceId: itemId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    });
                });
            }
            if (batchCount > 0) await batch.commit();
            if (notifications.length > 0) {
                const messages = notifications.map((notif) => ({
                    token: notif.token,
                    notification: notif.notification,
                    data: notif.data,
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {payload: {aps: {sound: "default", badge: 1}}},
                }));
                await admin.messaging().sendEach(messages);
            }
        };

        try {
            // 1. Process Badges
            const badgesSnapshot = await adminDb.collection("badges")
                .where("isActive", "==", true).get();
            for (const doc of badgesSnapshot.docs) {
                const badge = doc.data();
                if (badge.reminderNotification === false) continue;
                const endDate = badge.acquisitionRules?.timeframe?.endDate;
                const reminderDate = badge.reminderDate ?? 3;
                if (shouldSendReminder(endDate, reminderDate)) {
                    const name = badge.name || "";
                    const isDev = name.toLowerCase().includes("test dev");
                    let categories = badge.visibilityCriteria?.clientCategories;
                    if (!Array.isArray(categories) || categories.length === 0) {
                        categories = ["Pharmacie"];
                    } else {
                        categories = categories.map((c: string) =>
                            c === "" || c === "Pharmacie" ? "Pharmacie" : c);
                    }
                    const title = "Rappel : Badge bientôt expiré !";
                    const body = `Le badge "${name}" expire dans ` +
                        `${reminderDate} jours.`;
                    await sendRemindersToUsers(
                        "newBadge", doc.id, title, body, isDev, categories
                    );
                }
            }
            // 2. Process Goals
            const goalsSnapshot = await adminDb.collection("goals")
                .where("isActive", "==", true).get();
            for (const doc of goalsSnapshot.docs) {
                const goal = doc.data();
                if (goal.reminderNotification === false) continue;
                const endDate = goal.endDate;
                const reminderDate = goal.reminderDate ?? 3;
                if (shouldSendReminder(endDate, reminderDate)) {
                    const gTitle = goal.title || "";
                    const isDev = gTitle.toLowerCase().includes("test dev");
                    let categories = goal.criteria?.clientCategories || [];
                    if (!Array.isArray(categories) || categories.length === 0) {
                        categories = ["Pharmacie"];
                    } else {
                        categories = categories.map((c: string) =>
                            c === "" || c === "Pharmacie" ? "Pharmacie" : c);
                    }
                    const title = "Rappel : Objectif bientôt expiré !";
                    const body = `L'objectif "${gTitle}" expire dans ` +
                        `${reminderDate} jours.`;
                    await sendRemindersToUsers(
                        "newGoal", doc.id, title, body, isDev, categories
                    );
                }
            }
            // 3. Process Formations / Blog Posts
            const postsSnapshot = await adminDb.collection("blogPosts")
                .where("type", "in", ["formation", "actualité"]).get();
            for (const doc of postsSnapshot.docs) {
                const post = doc.data();
                if (post.reminderNotification === false) continue;
                const endDate = post.formationEndDate;
                const reminderDate = post.reminderDate ?? 3;
                if (shouldSendReminder(endDate, reminderDate)) {
                    const pTitle = post.title || "";
                    const isDev = pTitle.toLowerCase().includes("test dev");
                    const title = "Rappel : Formation bientôt expirée !";
                    const body = `La ressource "${pTitle}" expire dans ` +
                        `${reminderDate} jours.`;
                    await sendRemindersToUsers(
                        "newTraining", doc.id, title, body, isDev, null
                    );
                }
            }
        } catch (error) {
            console.error("Error in reminder notifications:", error);
        }
    });

/**
 * Sends a custom notification based on criteria.
 */
export const onNewCustomNotificationCreated = functions.firestore
    .document("customNotifications/{docId}")
    .onCreate(async (snap, context) => {
        const notifMsg = snap.data();
        const docId = context.params.docId;

        console.log(`New custom notification created: ${docId}`);

        try {
            const dbRef = admin.firestore();
            const [usersSnapshot, pharmaciesSnapshot] = await Promise.all([
                dbRef.collection("users").get(),
                dbRef.collection("pharmacies").get(),
            ]);

            const pharmacyCategoryMap = new Map<string, string>();
            pharmaciesSnapshot.docs.forEach((doc) => {
                const data = doc.data();
                pharmacyCategoryMap.set(
                    doc.id,
                    data.clientCategory || "Pharmacie"
                );
            });

            const batch = admin.firestore().batch();
            let batchCount = 0;
            interface FcmNotification {
                token: string;
                notification: {
                    title: string;
                    body: string;
                };
                data: {
                    type: string;
                    resourceId: string;
                    click_action: string;
                };
            }
            const notifications: FcmNotification[] = [];

            const targetRoles = notifMsg.roles || [];
            const targetPharmacies = notifMsg.pharmacyIds || [];
            const targetClientCategories = notifMsg.clientCategories || [];
            const targetCities = notifMsg.cities || [];
            const targetUserIds = notifMsg.userIds || [];

            for (const userDoc of usersSnapshot.docs) {
                const userId = userDoc.id;
                const userData = userDoc.data();
                const fcmToken = userData.fcmToken;

                let isEligible = true;

                if (targetUserIds.length > 0 &&
                    !targetUserIds.includes(userId)) {
                    isEligible = false;
                }
                if (targetRoles.length > 0 &&
                    !targetRoles.includes(userData.role)) {
                    isEligible = false;
                }
                if (targetPharmacies.length > 0 &&
                    !targetPharmacies.includes(userData.pharmacyId)) {
                    isEligible = false;
                }
                if (targetCities.length > 0 &&
                    !targetCities.includes(userData.city)) {
                    isEligible = false;
                }
                if (targetClientCategories.length > 0) {
                    const uPhId = userData.pharmacyId;
                    const uCat = uPhId ?
                        (pharmacyCategoryMap.get(uPhId) || "Pharmacie") :
                        "Pharmacie";
                    if (!targetClientCategories.includes(uCat)) {
                        isEligible = false;
                    }
                }

                if (!isEligible) continue;

                const notificationRef = admin.firestore()
                    .collection("users")
                    .doc(userId)
                    .collection("notifications")
                    .doc();

                batch.set(notificationRef, {
                    userId: userId,
                    title: notifMsg.title,
                    body: notifMsg.description,
                    type: "customNotification",
                    resourceId: docId,
                    imageUrl: notifMsg.imageUrl || null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                batchCount++;

                const userTokens: string[] = userData.fcmTokens ||
                    (fcmToken ? [fcmToken] : []);
                userTokens.forEach((token) => {
                    notifications.push({
                        token: token,
                        notification: {
                            title: notifMsg.title,
                            body: notifMsg.description,
                        },
                        data: {
                            type: "customNotification",
                            resourceId: docId,
                            click_action: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    });
                });
            }

            if (batchCount > 0) await batch.commit();
            console.log(`Created ${batchCount} notification documents`);

            if (notifications.length > 0) {
                const messages = notifications.map((notif) => ({
                    token: notif.token,
                    notification: notif.notification,
                    data: notif.data,
                    android: {
                        priority: "high" as const,
                        notification: {
                            channelId: "novopharma_channel",
                            sound: "default",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                }));

                const chunkSize = 500;
                for (let i = 0; i < messages.length; i += chunkSize) {
                    const chunk = messages.slice(i, i + chunkSize);
                    await admin.messaging().sendEach(chunk);
                }
            }

            await admin.firestore()
                .collection("customNotifications")
                .doc(docId).update({
                    status: "sent",
                    sentCount: batchCount,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                });

            return {success: true, sentCount: batchCount};
        } catch (error) {
            console.error("Error sending custom notifications:", error);
            await admin.firestore()
                .collection("customNotifications")
                .doc(docId).update({
                    status: "failed",
                    error: String(error),
                });
            return {success: false, error};
        }
    });
