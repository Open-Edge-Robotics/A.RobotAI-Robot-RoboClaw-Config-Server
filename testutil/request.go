package testutil

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
)

// PerformJSON 은 body 를 JSON 으로 인코딩해 요청을 보낸다.
// token 이 비어있지 않으면 Authorization: Bearer <token> 헤더를 추가한다.
func PerformJSON(router http.Handler, method, path, token string, body any) *httptest.ResponseRecorder {
	var bodyBytes []byte
	if body != nil {
		var err error
		bodyBytes, err = json.Marshal(body)
		if err != nil {
			panic(err)
		}
	}
	req := httptest.NewRequest(method, path, bytes.NewReader(bodyBytes))
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}
