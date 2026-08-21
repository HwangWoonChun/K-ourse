const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// 카카오 액세스 토큰 → Firebase Custom Token 교환
exports.kakaoCustomToken = onRequest(async (req, res) => {
    // CORS
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        res.status(204).send("");
        return;
    }

    const { accessToken } = req.body;
    if (!accessToken) {
        res.status(400).json({ error: "accessToken이 없습니다." });
        return;
    }

    try {
        // 1. 카카오 서버에서 사용자 정보 가져오기
        const kakaoResponse = await axios.get("https://kapi.kakao.com/v2/user/me", {
            headers: { Authorization: `Bearer ${accessToken}` },
        });

        const kakaoUserId = String(kakaoResponse.data.id);

        // 2. Firebase Custom Token 발급
        const firebaseToken = await admin.auth().createCustomToken(`kakao:${kakaoUserId}`);

        res.status(200).json({ firebaseToken });
    } catch (error) {
        console.error("카카오 Custom Token 발급 실패:", error.message);
        res.status(500).json({ error: "Custom Token 발급에 실패했습니다." });
    }
});
