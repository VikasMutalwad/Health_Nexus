import { getFirestore, collection, query, where, onSnapshot, updateDoc, doc } from "firebase/firestore";

// --- Doctor Portal: Trigger Video Call ---

export async function requestVideoCall(doctorId, patientId) {
    try {
        const response = await fetch('/api/video-call/request', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ doctor_id: doctorId, patient_id: patientId })
        });
        
        if (response.ok) {
            alert("Video call request sent to PHC.");
        } else {
            console.error("Failed to request call");
            alert("Could not send request.");
        }
    } catch (error) {
        console.error("Network error:", error);
    }
}

// --- PHC Portal: Real-time Listener & UI ---

export function listenForVideoCalls(patientId) {
    const db = getFirestore();
    const q = query(
        collection(db, "video_calls"),
        where("patient_id", "==", patientId),
        where("status", "==", "pending")
    );

    // Listen for new pending calls
    return onSnapshot(q, (snapshot) => {
        snapshot.docChanges().forEach((change) => {
            if (change.type === "added") {
                const callData = change.doc.data();
                showIncomingCallPopup(change.doc.id, callData.doctor_id);
            }
        });
    });
}

async function respondToCall(callId, status) {
    const db = getFirestore();
    try {
        await updateDoc(doc(db, "video_calls", callId), { status: status });
        const popup = document.getElementById(`call-popup-${callId}`);
        if (popup) popup.remove();
    } catch (error) {
        console.error("Error updating call status:", error);
    }
}

function showIncomingCallPopup(callId, doctorId) {
    const popup = document.createElement('div');
    popup.id = `call-popup-${callId}`;
    popup.style.cssText = "position:fixed;top:20px;right:20px;background:#fff;border:1px solid #ccc;padding:20px;z-index:9999;box-shadow:0 4px 12px rgba(0,0,0,0.15);border-radius:8px;";
    popup.innerHTML = `
        <h4 style="margin:0 0 10px 0;">Incoming Video Call</h4>
        <p style="margin-bottom:15px;">Doctor <strong>${doctorId}</strong> is requesting a call.</p>
        <button onclick="window.respondToCall('${callId}', 'accepted')" style="margin-right:10px;padding:8px 16px;background:#28a745;color:white;border:none;border-radius:4px;cursor:pointer;">Accept</button>
        <button onclick="window.respondToCall('${callId}', 'rejected')" style="padding:8px 16px;background:#dc3545;color:white;border:none;border-radius:4px;cursor:pointer;">Reject</button>
    `;
    document.body.appendChild(popup);
    
    // Expose helper to window for the inline onclick handlers
    window.respondToCall = respondToCall;
}