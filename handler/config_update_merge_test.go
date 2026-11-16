package handler

import (
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

func TestUpdateConfigPreservesFieldsOmittedByClient(t *testing.T) {
	h, db := setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name:             "original",
		RobotName:        "butler",
		Environment:      "office",
		IsActive:         true,
		RagTopK:          7,
		TaskQueueMaxSize: 12,
	}
	db.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", h.UpdateConfig)
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", map[string]any{"name": "renamed"})
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var updated models.RoboClawConfig
	if err := db.First(&updated, cfg.ID).Error; err != nil {
		t.Fatal(err)
	}
	if updated.Name != "renamed" || updated.RagTopK != 7 || updated.TaskQueueMaxSize != 12 || !updated.IsActive {
		t.Fatalf("omitted fields were not preserved: %+v", updated)
	}
}
