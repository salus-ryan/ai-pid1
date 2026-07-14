CC?=cc
CFLAGS?=-Os -s
all: init cortex
init: src/init.c
	$(CC) $(CFLAGS) -o rootfs/init $<
cortex:
	cd cortex-rs && cargo build --release
install: all
	install -D cortex-rs/target/release/cortex rootfs/sbin/cortex
	install -D cortex-rs/target/release/cactus-modeld rootfs/sbin/cactus-modeld
	install -D scripts/cactus_needle_decider.py rootfs/opt/cactus-needle-decider
	install -D src/watchdog.sh rootfs/sbin/watchdog
	mkdir -p rootfs/etc/init.d
	printf '#!/bin/sh\ntrue\n' > rootfs/etc/init.d/net; chmod +x rootfs/etc/init.d/net
	printf '#!/bin/sh\ntrue\n' > rootfs/etc/init.d/storage; chmod +x rootfs/etc/init.d/storage
run: install
	qemu-system-x86_64 -kernel bzImage -initrd rootfs.cpio.gz -append 'console=ttyS0 rdinit=/init' -nographic
cpio: install busybox
	cd rootfs && find . | cpio -H newc -o | gzip -9 > ../rootfs.cpio.gz
boot-smoke: cpio
	sh scripts/boot_smoke.sh
test: install
	rm -rf tmp-test; CORTEX_STATE=$$(pwd)/tmp-test timeout 7 rootfs/sbin/cortex || true
	test -s tmp-test/state.json && test -s tmp-test/journal.jsonl
busybox:
	sh scripts/bundle_busybox.sh
cactus-download:
	sh scripts/fetch_cactus.sh
eval: install
	python3 scripts/eval.py
clean:
	rm -f rootfs/init rootfs/sbin/cortex rootfs/sbin/cactus-modeld rootfs.cpio.gz
	cd cortex-rs && cargo clean
