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

        // Skip notification if post is for testing
        const postTitle = post?.title;
        if (
            typeof postTitle === "string" &&
            postTitle.toLowerCase().includes("test dev")
        ) {
            console.log(
                `Post ${postId} contains "test dev", ` +
                "skipping notification"
            );
            return {success: true, skipped: true};
        }

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
                if (fcmToken) {
                    notifications.push({
                        token: fcmToken,
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
                }
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

        // Skip notification if badge is for testing
        const badgeTitle = badge?.name;
        if (
            typeof badgeTitle === "string" &&
            badgeTitle.toLowerCase().includes("test dev")
        ) {
            console.log(
                `Badge ${badgeId} contains "test dev", ` +
                "skipping notification"
            );
            return {success: true, skipped: true};
        }

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
                if (fcmToken) {
                    notifications.push({
                        token: fcmToken,
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
                }
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
            const fcmToken = userData?.fcmToken;

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

            // Send FCM notification if user has a token
            if (fcmToken) {
                await admin.messaging().send({
                    token: fcmToken,
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
                        priority: "high",
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
                });
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

                    if (adminData.fcmToken) {
                        adminNotifications.push({
                            token: adminData.fcmToken,
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
                    }
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

        // Skip notification if goal is for testing
        const goalTitle = goal?.title;
        if (
            typeof goalTitle === "string" &&
            goalTitle.toLowerCase().includes("test dev")
        ) {
            console.log(
                `Goal ${goalId} contains "test dev", ` +
                "skipping notification"
            );
            return {success: true, skipped: true};
        }

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
                if (fcmToken) {
                    notifications.push({
                        token: fcmToken,
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
                }
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
                const fcmToken = userData?.fcmToken;

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

                // Send FCM notification if user has a token
                if (fcmToken) {
                    await admin.messaging().send({
                        token: fcmToken,
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
                            priority: "high",
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
                    });
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

                        if (adminData.fcmToken) {
                            adminNotifications.push({
                                token: adminData.fcmToken,
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
                        }
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
