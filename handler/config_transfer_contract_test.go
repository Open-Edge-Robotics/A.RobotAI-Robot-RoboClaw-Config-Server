package handler

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"ai-config-server/database/models"
)

func TestConfigTransferCoversProfileFields(t *testing.T) {
	transferFields := make(map[string]bool)
	transferType := reflect.TypeFor[ConfigTransfer]()
	for i := 0; i < transferType.NumField(); i++ {
		name := strings.Split(transferType.Field(i).Tag.Get("json"), ",")[0]
		transferFields[name] = true
	}

	modelType := reflect.TypeFor[models.RoboClawConfig]()
	for i := 0; i < modelType.NumField(); i++ {
		field := modelType.Field(i)
		// Embedded GORM metadata is deliberately excluded from portable backups.
		if field.Anonymous {
			continue
		}
		name := strings.Split(field.Tag.Get("json"), ",")[0]
		if name != "" && name != "-" && !transferFields[name] {
			t.Errorf("profile field %s is missing from the backup DTO", name)
		}
	}
}

func TestConfigTransferJSONRoundTripPreservesAllProfileFields(t *testing.T) {
	var cfg models.RoboClawConfig
	value := reflect.ValueOf(&cfg).Elem()
	for i := 0; i < value.NumField(); i++ {
		field := value.Field(i)
		if value.Type().Field(i).Anonymous {
			continue
		}
		switch field.Kind() {
		case reflect.String:
			field.SetString("fixture_" + value.Type().Field(i).Name)
		case reflect.Bool:
			field.SetBool(true)
		case reflect.Int:
			field.SetInt(123)
		case reflect.Float64:
			field.SetFloat(1.25)
		case reflect.Pointer:
			if field.Type().Elem().Kind() != reflect.Bool {
				t.Fatalf("unsupported fixture field: %s", value.Type().Field(i).Name)
			}
			field.Set(reflect.ValueOf(new(true)))
		default:
			t.Fatalf("unsupported fixture field: %s", value.Type().Field(i).Name)
		}
	}
	data, err := json.Marshal(configToTransfer(&cfg, true))
	if err != nil {
		t.Fatal(err)
	}
	var transfer ConfigTransfer
	if err := json.Unmarshal(data, &transfer); err != nil {
		t.Fatal(err)
	}
	restored := reflect.ValueOf(transfer.toModel(nil))
	for i := 0; i < value.NumField(); i++ {
		if value.Type().Field(i).Anonymous {
			continue
		}
		if !reflect.DeepEqual(value.Field(i).Interface(), restored.Field(i).Interface()) {
			t.Errorf("profile field %s changed through the JSON round trip", value.Type().Field(i).Name)
		}
	}
}

func TestConfigTransferGRPCJSONRoundTrip(t *testing.T) {
	cfg := models.RoboClawConfig{GrpcPort: 51052, GrpcPeerToken: "sample-peer-credential"}
	for _, includeSecrets := range []bool{false, true} {
		t.Run(map[bool]string{false: "without_secrets", true: "with_secrets"}[includeSecrets], func(t *testing.T) {
			data, err := json.Marshal(configToTransfer(&cfg, includeSecrets))
			if err != nil {
				t.Fatal(err)
			}
			var fields map[string]json.RawMessage
			if err := json.Unmarshal(data, &fields); err != nil {
				t.Fatal(err)
			}
			if _, included := fields["grpc_peer_token"]; included != includeSecrets {
				t.Fatalf("unexpected grpc_peer_token presence: %t", included)
			}
			var transfer ConfigTransfer
			if err := json.Unmarshal(data, &transfer); err != nil {
				t.Fatal(err)
			}
			restored := transfer.toModel(nil)
			if restored.GrpcPort != cfg.GrpcPort {
				t.Errorf("port changed through JSON round trip: got %d", restored.GrpcPort)
			}
			wantToken := ""
			if includeSecrets {
				wantToken = cfg.GrpcPeerToken
			}
			if restored.GrpcPeerToken != wantToken {
				t.Error("peer credential was not preserved according to export policy")
			}
		})
	}
}

func TestConfigTransferGRPCLegacyCompatibility(t *testing.T) {
	var transfer ConfigTransfer
	if err := json.Unmarshal([]byte(`{"name":"legacy","robot_name":"butler","environment":"office"}`), &transfer); err != nil {
		t.Fatal(err)
	}
	restored := transfer.toModel(nil)
	if restored.GrpcPort != 50052 || restored.GrpcPeerToken != "" {
		t.Error("legacy backup must use the compatible gRPC defaults on a fresh server")
	}
	existing := &models.RoboClawConfig{GrpcPort: 51052, GrpcPeerToken: "existing-peer-credential"}
	restored = transfer.toModel(existing)
	if restored.GrpcPort != existing.GrpcPort || restored.GrpcPeerToken != existing.GrpcPeerToken {
		t.Error("absent gRPC fields in a legacy backup must preserve existing values")
	}
}

func TestConfigTransferGRPCExplicitEmptyCredential(t *testing.T) {
	var transfer ConfigTransfer
	if err := json.Unmarshal([]byte(`{"grpc_port":51052,"grpc_peer_token":""}`), &transfer); err != nil {
		t.Fatal(err)
	}
	existing := &models.RoboClawConfig{GrpcPort: 50052, GrpcPeerToken: "existing-peer-credential"}
	restored := transfer.toModel(existing)
	if restored.GrpcPort != 51052 || restored.GrpcPeerToken != "" {
		t.Error("explicit values must override existing port and credential")
	}
}
