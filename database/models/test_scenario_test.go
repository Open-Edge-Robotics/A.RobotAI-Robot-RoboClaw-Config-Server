package models

import "testing"

// TestTestCaseListValue 는 커스텀 타입의 DB 직렬화를 검증한다.
func TestTestCaseListValue(t *testing.T) {
	list := TestCaseList{{ID: "tc1", Name: "Ping", Type: "ping", Enabled: true}}
	v, err := list.Value()
	if err != nil {
		t.Fatalf("Value failed: %v", err)
	}
	str, ok := v.(string)
	if !ok {
		t.Fatalf("expected string value, got %T", v)
	}
	if !contains(str, "tc1") {
		t.Errorf("expected value to contain tc1, got %q", str)
	}

	// 빈 목록 → "[]"
	empty := TestCaseList{}
	v, err = empty.Value()
	if err != nil {
		t.Fatalf("empty Value failed: %v", err)
	}
	if v != "[]" {
		t.Errorf("expected '[]', got %v", v)
	}
}

// TestTestCaseListScan 은 DB 역직렬화를 검증한다.
func TestTestCaseListScan(t *testing.T) {
	var list TestCaseList
	if err := list.Scan([]byte(`[{"id":"tc1","name":"Ping","type":"ping","enabled":true}]`)); err != nil {
		t.Fatalf("Scan failed: %v", err)
	}
	if len(list) != 1 || list[0].ID != "tc1" {
		t.Fatalf("expected 1 test case, got %+v", list)
	}

	// nil → 빈 목록
	var nilList TestCaseList
	if err := nilList.Scan(nil); err != nil {
		t.Fatalf("nil Scan failed: %v", err)
	}
	if len(nilList) != 0 {
		t.Errorf("expected empty list, got %d", len(nilList))
	}

	// string 입력
	var strList TestCaseList
	if err := strList.Scan(`[{"id":"a"}]`); err != nil {
		t.Fatalf("string Scan failed: %v", err)
	}
	if len(strList) != 1 {
		t.Errorf("expected 1 element, got %d", len(strList))
	}

	// 잘못된 타입 → 에러
	var bad TestCaseList
	if err := bad.Scan(123); err == nil {
		t.Error("expected error for invalid scan type")
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
