DESIGN   = ram_axi
RUN_TAG  = run1
LL_FLAGS = --run-tag $(RUN_TAG) --overwrite --skip KLayout.Render --skip KLayout.DRC

.PHONY: asic_run asic_verify asic_clean

asic_run:
	rm -rf runs/$(RUN_TAG)
	mkdir -p run
	librelane config.yaml $(LL_FLAGS)
	bash scripts/collect_outputs.sh $(RUN_TAG)
	@echo ">> asic_run tamamlandi"

asic_verify:
	@bash scripts/verify_outputs.sh

asic_clean:
	rm -rf runs/$(RUN_TAG)
	@echo ">> Temizlendi"
