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

        // Only send notification if it's a training post
        if (post.type !== "formation") {
            console.log(
                `Post ${postId} is not a training, ` +
                "skipping notification"
            );
            return {success: true, skipped: true};
        }

        console.log(`New training created: ${postId}`);

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
                    title: "Nouvelle formation disponible !",
                    body:
                        post.title ||
                        "Une nouvelle formation vient d'être publiée",
                    type: "newTraining",
                    resourceId: postId,
                    imageUrl: post.imageUrl || null,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Prepare FCM message if user has a token
                if (fcmToken) {
                    notifications.push({
                        token: fcmToken,
                        notification: {
                            title: "Nouvelle formation disponible !",
                            body:
                                post.title ||
                                "Une nouvelle formation vient d'être publiée",
                        },
                        data: {
                            type: "newTraining",
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
