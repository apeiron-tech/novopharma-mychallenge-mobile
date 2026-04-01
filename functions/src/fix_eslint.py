def wrap_long_lines(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    for i in [84, 252, 341, 442, 605, 708, 811, 955, 1165]:
        line = lines[i]
        
        # Line 84: const userTokens = userData.fcmTokens || (fcmToken ? [fcmToken] : []);
        if "userData.fcmTokens ||" in line:
            parts = line.split("userData.fcmTokens ||")
            indent = line[:len(line) - len(line.lstrip())]
            lines[i] = parts[0] + "userData.fcmTokens ||\n" + indent + "    " + parts[1].lstrip()
            
        # Line 341: const fcmTokens: string[] = userData?.fcmTokens || (userData?.fcmToken ? [userData?.fcmToken] : []);
        elif "fcmTokens: string[]" in line:
            parts = line.split("||")
            indent = line[:len(line) - len(line.lstrip())]
            lines[i] = parts[0] + "||\n" + indent + "    " + parts[1].lstrip()
            
        # Line 442: const adminTokens: string[] = adminData.fcmTokens || (adminData.fcmToken ? [adminData.fcmToken] : []);
        elif "adminTokens: string[]" in line:
            parts = line.split("||")
            indent = line[:len(line) - len(line.lstrip())]
            lines[i] = parts[0] + "||\n" + indent + "    " + parts[1].lstrip()
            

    with open(file_path, "w", encoding="utf-8") as f:
        f.writelines(lines)

wrap_long_lines("C:/Users/imadb/Desktop/Apeiron Technologies/novoPharma/novopharma-mychallenge-mobile/functions/src/notifications.ts")
