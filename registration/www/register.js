const form = document.getElementById("register-form");
const usernameInput = document.getElementById("username");
const usernamePreview = document.getElementById("username-preview");
const messageDiv = document.getElementById("message");

usernameInput.addEventListener("input", () => {
    const value = usernameInput.value.toLowerCase().trim();
    usernamePreview.textContent = value || "username";
});

form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const button = form.querySelector("button");
    button.disabled = true;
    button.textContent = "Registering...";
    messageDiv.hidden = true;

    const body = {
        username: usernameInput.value.trim().toLowerCase(),
        password: document.getElementById("password").value,
        invite_code: document.getElementById("invite-code").value,
    };

    try {
        const resp = await fetch("/api/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });

        const data = await resp.json();

        if (resp.ok) {
            showMessage("success", `Account created! You can now sign in as @${body.username}:ohana-matrix.xyz using any Matrix client.`);
            form.reset();
            usernamePreview.textContent = "username";
        } else {
            showMessage("error", data.error || "Registration failed.");
        }
    } catch {
        showMessage("error", "Could not reach the server. Please try again.");
    } finally {
        button.disabled = false;
        button.textContent = "Register";
    }
});

function showMessage(type, text) {
    messageDiv.textContent = text;
    messageDiv.className = type;
    messageDiv.hidden = false;
}
