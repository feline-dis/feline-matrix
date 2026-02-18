package main

import (
	"crypto/hmac"
	"crypto/sha1"
	"embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strings"
)

//go:embed www/*
var staticFiles embed.FS

var usernamePattern = regexp.MustCompile(`^[a-z0-9._=\-/]+$`)

func main() {
	sharedSecret := os.Getenv("REGISTRATION_SHARED_SECRET")
	if sharedSecret == "" {
		log.Fatal("REGISTRATION_SHARED_SECRET is not set")
	}

	inviteCode := os.Getenv("INVITE_CODE")
	if inviteCode == "" {
		log.Fatal("INVITE_CODE is not set")
	}

	dendriteURL, _ := url.Parse("http://localhost:8009")
	proxy := httputil.NewSingleHostReverseProxy(dendriteURL)

	wwwFS, err := fs.Sub(staticFiles, "www")
	if err != nil {
		log.Fatal(err)
	}
	fileServer := http.FileServer(http.FS(wwwFS))

	mux := http.NewServeMux()

	mux.Handle("/register/", http.StripPrefix("/register/", fileServer))
	mux.HandleFunc("/register", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/register/", http.StatusMovedPermanently)
	})

	mux.HandleFunc("/api/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		handleRegistration(w, r, sharedSecret, inviteCode, dendriteURL.String())
	})

	mux.Handle("/", proxy)

	log.Println("registration proxy listening on :8008")
	log.Fatal(http.ListenAndServe(":8008", mux))
}

type registrationRequest struct {
	Username   string `json:"username"`
	Password   string `json:"password"`
	InviteCode string `json:"invite_code"`
}

type nonceResponse struct {
	Nonce string `json:"nonce"`
}

func handleRegistration(w http.ResponseWriter, r *http.Request, sharedSecret, inviteCode, dendriteBase string) {
	var req registrationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	if req.InviteCode != inviteCode {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "invalid invite code"})
		return
	}

	req.Username = strings.TrimSpace(strings.ToLower(req.Username))

	if req.Username == "" || req.Password == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "username and password are required"})
		return
	}

	if len(req.Username) > 255 || !usernamePattern.MatchString(req.Username) {
		writeJSON(w, http.StatusBadRequest, map[string]string{
			"error": "username must contain only lowercase letters, numbers, dots, underscores, hyphens, equals, and slashes",
		})
		return
	}

	if len(req.Password) < 8 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "password must be at least 8 characters"})
		return
	}

	// Step 1: Get a nonce from Dendrite
	nonceResp, err := http.Get(dendriteBase + "/_synapse/admin/v1/register")
	if err != nil {
		log.Printf("failed to get nonce: %v", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "failed to contact homeserver"})
		return
	}
	defer nonceResp.Body.Close()

	var nonce nonceResponse
	if err := json.NewDecoder(nonceResp.Body).Decode(&nonce); err != nil {
		log.Printf("failed to decode nonce response: %v", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "unexpected response from homeserver"})
		return
	}

	// Step 2: Compute HMAC-SHA1 of nonce\0username\0password\0notadmin
	mac := hmac.New(sha1.New, []byte(sharedSecret))
	mac.Write([]byte(fmt.Sprintf("%s\x00%s\x00%s\x00notadmin", nonce.Nonce, req.Username, req.Password)))
	hmacHex := hex.EncodeToString(mac.Sum(nil))

	// Step 3: Register with Dendrite using the HMAC
	regBody := map[string]interface{}{
		"nonce":    nonce.Nonce,
		"username": req.Username,
		"password": req.Password,
		"mac":      hmacHex,
		"admin":    false,
	}

	regJSON, _ := json.Marshal(regBody)
	regResp, err := http.Post(
		dendriteBase+"/_synapse/admin/v1/register",
		"application/json",
		strings.NewReader(string(regJSON)),
	)
	if err != nil {
		log.Printf("failed to register user: %v", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "failed to contact homeserver"})
		return
	}
	defer regResp.Body.Close()

	body, _ := io.ReadAll(regResp.Body)

	if regResp.StatusCode != http.StatusOK {
		var errResp map[string]interface{}
		if json.Unmarshal(body, &errResp) == nil {
			if errMsg, ok := errResp["error"].(string); ok {
				writeJSON(w, regResp.StatusCode, map[string]string{"error": errMsg})
				return
			}
		}
		writeJSON(w, regResp.StatusCode, map[string]string{"error": "registration failed"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "message": "account created successfully"})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
