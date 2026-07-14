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
usb-tree: kernel cpio
	sh scripts/make_usb_tree.sh
usb-image: usb-tree
	sh scripts/make_usb_image.sh
export-artifacts:
	sh scripts/export_windows_artifacts.sh
windows-artifacts: mvp export-artifacts
portable-usb: kernel cpio
	sh scripts/make_portable_usb.sh
test: install
	rm -rf tmp-test; CORTEX_STATE=$$(pwd)/tmp-test timeout 7 rootfs/sbin/cortex || true
	test -s tmp-test/state.json && test -s tmp-test/journal.jsonl
busybox:
	sh scripts/bundle_busybox.sh
kernel:
	sh scripts/fetch_kernel.sh
cactus-download:
	sh scripts/fetch_cactus.sh
eval: install
	python3 scripts/eval.py
.:
	@true
mvp:
	sh scripts/mvp_check.sh
clean:
	rm -f rootfs/init rootfs/sbin/cortex rootfs/sbin/cactus-modeld rootfs.cpio.gz ai-pid1-usb.tar.gz ai-pid1-usb.iso ai-cortex-usb.tar.gz ai-cortex-usb.img mvp-check.log boot-smoke.log
	rm -rf ai-pid1-usb ai-cortex-usb
	cd cortex-rs && cargo clean
