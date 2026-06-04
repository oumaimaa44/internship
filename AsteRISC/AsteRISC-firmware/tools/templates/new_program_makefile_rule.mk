.PHONY: ${RULE_NAME}
${RULE_NAME}: libs_asterisc
	@+$(MAKE) -C $@ --no-print-directory
