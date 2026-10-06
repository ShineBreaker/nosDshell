;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; Vendored Rust crate sources for the nosDshell tool packages.
;;; Generated, do not edit by hand - regenerate with:
;;;
;;;   guix import crate --lockfile=tools/<name>/Cargo.lock <name>
;;;
;;; and re-split into this file, deduping against the sets above.
;;; The input lists at the end cover every entry of each lockfile.

(define-module (rust-crates)
  #:use-module (guix build-system cargo)
  #:export (nosd-blur-cargo-inputs
            nosd-theme-cargo-inputs
            nosd-helpers-cargo-inputs))

;;; nosd-blur crate sources — generated, do not edit by hand.

(define rust-adler2-2.0.1
  (crate-source "adler2" "2.0.1"
                "1ymy18s9hs7ya1pjc9864l30wk8p2qfqdi7mhhcc5nfakxbij09j"))

(define rust-autocfg-1.5.1
  (crate-source "autocfg" "1.5.1"
                "0lqasy5i30flcgih1b50kvsk6z32g09r1q4ql7q81pj6228jy0zj"))

(define rust-bitflags-2.13.2
  (crate-source "bitflags" "2.13.2"
                "01hbgjwvid66850fzi76mvn5f2bqycx6sf165ng1kfjqq9bl1v9x"))

(define rust-bytemuck-1.25.2
  (crate-source "bytemuck" "1.25.2"
                "15rp2m7j7kq22s76cbjwmrkd5r8lvacnm0mnrj013cnzka22x0wm"))

(define rust-byteorder-lite-0.1.0
  (crate-source "byteorder-lite" "0.1.0"
                "15alafmz4b9az56z6x7glcbcb6a8bfgyd109qc3bvx07zx4fj7wg"))

(define rust-cfg-if-1.0.5
  (crate-source "cfg-if" "1.0.5"
                "0026j56901nzjraap3da0a8njw42j66zcxnn6s2s9aa5bcblhxjf"))

(define rust-crc32fast-1.5.2
  (crate-source "crc32fast" "1.5.2"
                "0y0f955n2hr5a8rd9nw9sr23nhjc42ddx3bjc47dnlmqssgpk9q1"))

(define rust-fdeflate-0.3.7
  (crate-source "fdeflate" "0.3.7"
                "130ga18vyxbb5idbgi07njymdaavvk6j08yh1dfarm294ssm6s0y"))

(define rust-flate2-1.1.10
  (crate-source "flate2" "1.1.10"
                "1jvd2cl8j5hyf8imi62y1x7gwzz1hajirni0801yxhds1qp4wqvf"))

(define rust-image-0.25.8
  (crate-source "image" "0.25.8"
                "1rwill018gn2kwzv332kfs72ns0kwwnfxwacbhvk9lk9cwzfp7sj"))

(define rust-image-webp-0.2.4
  (crate-source "image-webp" "0.2.4"
                "1hz814csyi9283vinzlkix6qpnd6hs3fkw7xl6z2zgm4w7rrypjj"))

(define rust-miniz-oxide-0.8.9
  (crate-source "miniz_oxide" "0.8.9"
                "05k3pdg8bjjzayq3rf0qhpirq9k37pxnasfn4arbs17phqn6m9qz"))

(define rust-miniz-oxide-0.9.1
  (crate-source "miniz_oxide" "0.9.1"
                "0k2bgjzk2sbsynpsv4wizwxbqp6vs7g08y5anbkrh3l6a15bqgxn"))

(define rust-moxcms-0.7.11
  (crate-source "moxcms" "0.7.11"
                "15qa5znj029i7677l0hdv0lwmjggrg920bhjgs3cjvydb72mg5dc"))

(define rust-num-traits-0.2.19
  (crate-source "num-traits" "0.2.19"
                "0h984rhdkkqd4ny9cif7y2azl3xdfb7768hb9irhpsch4q3gq787"))

(define rust-png-0.18.1
  (crate-source "png" "0.18.1"
                "0qca282xp8a6d7mikxrwji3f52mjn4vnqxz2v9iz5adj665rnxk0"))

(define rust-pxfm-0.1.30
  (crate-source "pxfm" "0.1.30"
                "1slrnbxd0nc96sny6x50ss1sm9ci0gig0fp1w8mw0pkgm5prapfm"))

(define rust-quick-error-2.0.1
  (crate-source "quick-error" "2.0.1"
                "18z6r2rcjvvf8cn92xjhm2qc3jpd1ljvcbf12zv0k9p565gmb4x9"))

(define rust-simd-adler32-0.3.10
  (crate-source "simd-adler32" "0.3.10"
                "1sny4y2qa5mwyxx5x59ln2p02vsdh92004njlslnx98imjc9489s"))

(define rust-zlib-rs-0.6.8
  (crate-source "zlib-rs" "0.6.8"
                "04j158293bx73kv5pj1i89ai411q7fxc9zwk3wkpqgb9gj7fas5j"))

(define rust-zune-core-0.4.12
  (crate-source "zune-core" "0.4.12"
                "0jj1ra86klzlcj9aha9als9d1dzs7pqv3azs1j3n96822wn3lhiz"))

(define rust-zune-jpeg-0.4.21
  (crate-source "zune-jpeg" "0.4.21"
                "04r7g6y9jp7d4c9bq23rz3gwzlr1dsl7vdk4yly35bc4jf52rki9"))

;;; Equivalent of what `guix import -i' inserts under
;;; (define-cargo-inputs lookup-cargo-inputs (nosd-blur => ...)); kept as a
;;; plain list because the lookup table cannot be resolved across modules
;;; when building via `guix build -f'.
(define nosd-blur-cargo-inputs
  (list rust-adler2-2.0.1
        rust-autocfg-1.5.1
        rust-bitflags-2.13.2
        rust-bytemuck-1.25.2
        rust-byteorder-lite-0.1.0
        rust-cfg-if-1.0.5
        rust-crc32fast-1.5.2
        rust-fdeflate-0.3.7
        rust-flate2-1.1.10
        rust-image-0.25.8
        rust-image-webp-0.2.4
        rust-miniz-oxide-0.8.9
        rust-miniz-oxide-0.9.1
        rust-moxcms-0.7.11
        rust-num-traits-0.2.19
        rust-png-0.18.1
        rust-pxfm-0.1.30
        rust-quick-error-2.0.1
        rust-simd-adler32-0.3.10
        rust-zlib-rs-0.6.8
        rust-zune-core-0.4.12
        rust-zune-jpeg-0.4.21))

;;; nosd-theme crate sources - generated with
;;;   guix import crate --lockfile=tools/nosd-theme/Cargo.lock nosd-theme
;;; (deduped against the nosd-blur set above).

(define rust-equivalent-1.0.2
  (crate-source "equivalent" "1.0.2"
                "03swzqznragy8n0x31lqc78g2af054jwivp7lkrbrc0khz74lyl7"))
(define rust-flate2-1.1.2
  (crate-source "flate2" "1.1.2"
                "07abz7v50lkdr5fjw8zaw2v8gm2vbppc0f7nqm8x3v3gb6wpsgaa"))
(define rust-hashbrown-0.17.1
  (crate-source "hashbrown" "0.17.1"
                "0jmqz7i4yl6cm7rbn0i2ffkfrmwi6xkmzkaldr2v8bcsx2v0jngd"))
(define rust-indexmap-2.14.2
  (crate-source "indexmap" "2.14.2"
                "0mf86hbjkkcd82cpq683bblbs0zwa8ndla96ci8p1ji6bl7ijknc"))
(define rust-itoa-1.0.18
  (crate-source "itoa" "1.0.18"
                "10jnd1vpfkb8kj38rlkn2a6k02afvj3qmw054dfpzagrpl6achlg"))
(define rust-memchr-2.8.3
  (crate-source "memchr" "2.8.3"
                "161xa63ipfanf8v3nb82xd5hqgydv55nzw59wyngqbz6alfaz2yg"))
(define rust-proc-macro2-1.0.107
  (crate-source "proc-macro2" "1.0.107"
                "1nb6ly8kp65f724kj73ippc7lvydss24sm2vagk6qpklpg4pwplq"))
(define rust-quote-1.0.47
  (crate-source "quote" "1.0.47"
                "00ch0yyzvv6s671ik0kcsbw8nigdaj2g3fr61kcahwx48aqlvgqz"))
(define rust-serde-1.0.229
  (crate-source "serde" "1.0.229"
                "1fp04fq4a79bpm61xz1zy0pbz4kpc7d771zii1k3inmszq55jj21"))
(define rust-serde-core-1.0.229
  (crate-source "serde_core" "1.0.229"
                "0j1ajiha76h3nmd976il9li6975k121xa7jb39ws8n0yqp4s5p37"))
(define rust-serde-derive-1.0.229
  (crate-source "serde_derive" "1.0.229"
                "0j4k63i7h1bikxwz2c89ig0hrwbnl9mz1czn85xx99x5cc9dg9g7"))
(define rust-serde-json-1.0.151
  (crate-source "serde_json" "1.0.151"
                "051zww7lvpw147vvwss1ng6w587qyrkzg75fvj08q2dfrmgbahf8"))
(define rust-serde-spanned-1.1.1
  (crate-source "serde_spanned" "1.1.1"
                "09jzk7i6wihn3d8i3wi4j4n98ghi93c3b8m8k64nxq0ijn3vaqk6"))
(define rust-syn-3.0.6
  (crate-source "syn" "3.0.6"
                "1vmw7s58rzrs926nv5m06x7qbgswm1aa9iw3s1bj5var47kyi4w5"))
(define rust-toml-1.1.6+spec-1.1.0
  (crate-source "toml" "1.1.6+spec-1.1.0"
                "0sj0g89pyrkm9g5zaaqsdlclr98xf1chvi8jv9qsn4897xa041lj"))
(define rust-toml-datetime-1.1.1+spec-1.1.0
  (crate-source "toml_datetime" "1.1.1+spec-1.1.0"
                "1mws2mkkf46l7inn77azhm0vdwxngv9vsbhbl0ah33p2c9gzcr9i"))
(define rust-toml-parser-1.1.3+spec-1.1.0
  (crate-source "toml_parser" "1.1.3+spec-1.1.0"
                "0mjdvihdkmjd4ykh574xgii71hpxw7ns7h4n4bisqpxrz4faqf0x"))
(define rust-toml-writer-1.1.2+spec-1.1.0
  (crate-source "toml_writer" "1.1.2+spec-1.1.0"
                "1lk6pqf9mac3v1x6282n6a66qx5b18c8f4a23bsd0nk658x3amkx"))
(define rust-unicode-ident-1.0.26
  (crate-source "unicode-ident" "1.0.26"
                "0m3915ipi4zz7isncf5k1dz47ys0nq9j7l4l2n2rm03zaxwg8ifj"))
(define rust-winnow-1.0.4
  (crate-source "winnow" "1.0.4"
                "10fzxipa7lx16172p3aca9j60hzbqgjki2f95kqksd5qywcp7f93"))
(define rust-zmij-1.0.23
  (crate-source "zmij" "1.0.23"
                "06zwri21nnrl34rwinmvbciap8yk1mrl8qfg9pff7lgspc56sri9"))

;;; nosd-helpers crate sources - generated with
;;;   guix import crate --lockfile=tools/nosd-helpers/Cargo.lock nosd-helpers
;;; (deduped against the sets above).

(define rust-android-system-properties-0.1.6
  (crate-source "android_system_properties" "0.1.6"
                "1g3z4ga15a9022vbgi31qqyb7pgk23saq7xfarn6yslpr54ic8mf"))
(define rust-anyhow-1.0.104
  (crate-source "anyhow" "1.0.104"
                "0w34jjcm02p5g9kvsjr1dvpw0zs2fi7igi6nr414fkm5gz85w2ik"))
(define rust-async-broadcast-0.7.2
  (crate-source "async-broadcast" "0.7.2"
                "0ckmqcwyqwbl2cijk1y4r0vy60i89gqc86ijrxzz5f2m4yjqfnj3"))
(define rust-async-channel-2.5.0
  (crate-source "async-channel" "2.5.0"
                "1ljq24ig8lgs2555myrrjighycpx2mbjgrm3q7lpa6rdsmnxjklj"))
(define rust-async-executor-1.14.0
  (crate-source "async-executor" "1.14.0"
                "0al1rmxjy7p7r6h50z698q5lwssqs5a2vzmqbazm1z2sv1rgjsy9"))
(define rust-async-io-2.6.0
  (crate-source "async-io" "2.6.0"
                "1z16s18bm4jxlmp6rif38mvn55442yd3wjvdfhvx4hkgxf7qlss5"))
(define rust-async-lock-3.4.2
  (crate-source "async-lock" "3.4.2"
                "04c3xrrdrfrvh9v0ajxrangpy38qi76qq268zslphnxxjqjpy3r9"))
(define rust-async-process-2.5.0
  (crate-source "async-process" "2.5.0"
                "0xfswxmng6835hjlfhv7k0jrfp7czqxpfj6y2s5dsp05q0g94l7w"))
(define rust-async-recursion-1.2.0
  (crate-source "async-recursion" "1.2.0"
                "0lg4v61ax9wnfb5b5m11895qddcmq5a6h57cihf6n9mdp89br2jg"))
(define rust-async-signal-0.2.14
  (crate-source "async-signal" "0.2.14"
                "11dlpb15la279r5cazppy18gbk2xzzl60ahzl19m1kr0l2psmdaj"))
(define rust-async-task-4.7.1
  (crate-source "async-task" "4.7.1"
                "1pp3avr4ri2nbh7s6y9ws0397nkx1zymmcr14sq761ljarh3axcb"))
(define rust-async-trait-0.1.92
  (crate-source "async-trait" "0.1.92"
                "0rqn5iga1hlv2lm8xzav1zhar46jb4dvx89i6kfv93kb53maxxl2"))
(define rust-atomic-waker-1.1.2
  (crate-source "atomic-waker" "1.1.2"
                "1h5av1lw56m0jf0fd3bchxq8a30xv0b4wv8s4zkp4s0i7mfvs18m"))
(define rust-base64-0.23.1
  (crate-source "base64" "0.23.1"
                "19cdw4vh3d8qndbxjmbf6ddvmpicyddg704b4fjxjlchz7ncs1xc"))
(define rust-bitflags-1.3.2
  (crate-source "bitflags" "1.3.2"
                "12ki6w8gn1ldq7yz9y680llwk5gmrhrzszaa17g1sbrw2r2qvwxy"))
(define rust-blocking-1.7.0
  (crate-source "blocking" "1.7.0"
                "1ykd0gj18r4v4b8r692hds5dsg2w6y9fq4nlxs2l7fbcvwll63m7"))
(define rust-bumpalo-3.20.3
  (crate-source "bumpalo" "3.20.3"
                "0jc6va3nwcqikm7chnpdv1s87my3gs2j7g1sc7g3k91brg3arxbj"))
(define rust-bytes-1.12.1
  (crate-source "bytes" "1.12.1"
                "017z19dpg4f942h051m7bpnzcgng042hhcpd7bmg7bjjqd42lrgw"))
(define rust-cc-1.6.0
  (crate-source "cc" "1.6.0"
                "0c3n82hdi355xa6z9x4zgnpjwsh1szkkcs0zl8q8nl5ggk874j7p"))
(define rust-cfg-aliases-0.1.1
  (crate-source "cfg_aliases" "0.1.1"
                "17p821nc6jm830vzl2lmwz60g3a30hcm33nk6l257i1rjdqw85px"))
(define rust-chrono-0.4.45
  (crate-source "chrono" "0.4.45"
                "09rkcgk6is2sdhqs9142zv8xqnj8ryx8m9hknllqwyv9wxi9x9qs"))
(define rust-chrono-tz-0.10.4
  (crate-source "chrono-tz" "0.10.4"
                "1hr6rmdvqwgk748g2f69mnk97fzhdkfzaczvdn0wz4pdjy2rl4x6"))
(define rust-concurrent-queue-2.5.0
  (crate-source "concurrent-queue" "2.5.0"
                "0wrr3mzq2ijdkxwndhf79k952cp4zkz35ray8hvsxl96xrx1k82c"))
(define rust-core-foundation-sys-0.8.7
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "core-foundation-sys" "0.8.7"
                "12w8j73lazxmr1z0h98hf3z623kl8ms7g07jch7n4p8f9nwlhdkp"))
(define rust-crossbeam-utils-0.8.23
  (crate-source "crossbeam-utils" "0.8.23"
                "1ilan2nw7fvka8hki80fr57a5dgd4mvcsvwq60437j6yvlwyw7m3"))
(define rust-downcast-rs-1.2.1
  (crate-source "downcast-rs" "1.2.1"
                "1lmrq383d1yszp7mg5i7i56b17x2lnn3kb91jwsq0zykvg2jbcvm"))
(define rust-endi-1.1.1
  (crate-source "endi" "1.1.1"
                "16a0076dx41vgrzzimm9clcym77h732czqjiajanmzvd1i1y5dv6"))
(define rust-enumflags2-0.7.12
  (crate-source "enumflags2" "0.7.12"
                "1vzcskg4dca2jiflsfx1p9yw1fvgzcakcs7cpip0agl51ilgf9qh"))
(define rust-enumflags2-derive-0.7.12
  (crate-source "enumflags2_derive" "0.7.12"
                "09rqffacafl1b83ir55hrah9gza0x7pzjn6lr6jm76fzix6qmiv7"))
(define rust-errno-0.3.14
  (crate-source "errno" "0.3.14"
                "1szgccmh8vgryqyadg8xd58mnwwicf39zmin3bsn63df2wbbgjir"))
(define rust-event-listener-5.4.2
  (crate-source "event-listener" "5.4.2"
                "1lk9sv7r07l58jk263s18896l55mx9jv0g1rm4hj2mpi3paas8ss"))
(define rust-event-listener-strategy-0.5.4
  (crate-source "event-listener-strategy" "0.5.4"
                "14rv18av8s7n8yixg38bxp5vg2qs394rl1w052by5npzmbgz7scb"))
(define rust-fastrand-2.5.0
  (crate-source "fastrand" "2.5.0"
                "08q2r30y62winysimnlpbvw9kiwn0rmdlidqlmzd6z90mv764z6s"))
(define rust-filedescriptor-0.8.3
  (crate-source "filedescriptor" "0.8.3"
                "0bb8qqa9h9sj2mzf09yqxn260qkcqvmhmyrmdjvyxcn94knmh1z4"))
(define rust-find-msvc-tools-0.1.14
  (crate-source "find-msvc-tools" "0.1.14"
                "112ljldlv150fpl8xr2jl5czg51k3kdfn6cy5fqdsvkl14sgpp5f"))
(define rust-futures-core-0.3.34
  (crate-source "futures-core" "0.3.34"
                "0pjgv4fx0np6hrs5sz5a2phabwv0z70yr51v03injbi44bjrkmlj"))
(define rust-futures-io-0.3.34
  (crate-source "futures-io" "0.3.34"
                "1v9z6wj92ra18kpv0xig21hgpzrvcwmcr8fszyzh64yyay0zmh2k"))
(define rust-futures-lite-2.6.1
  (crate-source "futures-lite" "2.6.1"
                "1ba4dg26sc168vf60b1a23dv1d8rcf3v3ykz2psb7q70kxh113pp"))
(define rust-futures-task-0.3.34
  (crate-source "futures-task" "0.3.34"
                "1zfilqs8nwlfqz4prk7ihvpp5avvzins87ibzlxzq5fhs7ipshfd"))
(define rust-futures-util-0.3.34
  (crate-source "futures-util" "0.3.34"
                "1g3r9ghzq7c2fh34lis43i72xavk9p84npgfwgb5vfpqcwjajl0d"))
(define rust-getrandom-0.2.17
  (crate-source "getrandom" "0.2.17"
                "1l2ac6jfj9xhpjjgmcx6s1x89bbnw9x6j9258yy6xjkzpq0bqapz"))
(define rust-getrandom-0.4.3
  (crate-source "getrandom" "0.4.3"
                "16b0202fkdwz3p2cyll82dv24ljbn0wiyy829v4lwbkbflyqh3ih"))
(define rust-hermit-abi-0.5.3
  (crate-source "hermit-abi" "0.5.3"
                "115jzi6ixx2nhkzbr2ijj36634agz32n6ilz2rg7vk5s1vb94xg1"))
(define rust-hex-0.4.3
  (crate-source "hex" "0.4.3"
                "0w1a4davm1lgzpamwnba907aysmlrnygbqmfis2mqjx5m552a93z"))
(define rust-http-1.5.0
  (crate-source "http" "1.5.0"
                "1q4wpz5hb4cf37g3jrdyffrpa6ngidmd9wrfph92fddzprl3b3ci"))
(define rust-httparse-1.10.1
  (crate-source "httparse" "1.10.1"
                "11ycd554bw2dkgw0q61xsa7a4jn1wb1xbfacmf3dbwsikvkkvgvd"))
(define rust-iana-time-zone-0.1.65
  (crate-source "iana-time-zone" "0.1.65"
                "0w64khw5p8s4nzwcf36bwnsmqzf61vpwk9ca1920x82bk6nwj6z3"))
(define rust-iana-time-zone-haiku-0.1.2
  (crate-source "iana-time-zone-haiku" "0.1.2"
                "17r6jmj31chn7xs9698r122mapq85mfnv98bb4pg6spm0si2f67k"))
(define rust-js-sys-0.3.106
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "js-sys" "0.3.106"
                "1icwmpjw54lb7vg5926k5y4y5jbiih0zxhwgjwnzn475v90xk0vq"))
(define rust-lazy-static-1.5.1
  (crate-source "lazy_static" "1.5.1"
                "1yqaqmp510xw2ldpw88mx9b5s5qj8flb4rw0wd9ks1zpk9j0z1r0"))
(define rust-libc-0.2.190
  (crate-source "libc" "0.2.190"
                "0y5yap4bfp7rfsldcbk9pb5alcgygca5xn1n2pmh181zdpf3spff"))
(define rust-linux-raw-sys-0.12.1
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "linux-raw-sys" "0.12.1"
                "0lwasljrqxjjfk9l2j8lyib1babh2qjlnhylqzl01nihw14nk9ij"))
(define rust-log-0.4.34
  (crate-source "log" "0.4.34"
                "1ihkzn0m33ab79fcl4mkb04n5iwqzbxzyw7l7hazqkffaqzbvy7r"))
(define rust-memoffset-0.9.1
  (crate-source "memoffset" "0.9.1"
                "12i17wh9a9plx869g7j4whf62xw68k5zd4k0k5nh6ys5mszid028"))
(define rust-nix-0.28.0
  (crate-source "nix" "0.28.0"
                "1r0rylax4ycx3iqakwjvaa178jrrwiiwghcw95ndzy72zk25c8db"))
(define rust-once-cell-1.21.4
  (crate-source "once_cell" "1.21.4"
                "0l1v676wf71kjg2khch4dphwh1jp3291ffiymr2mvy1kxd5kwz4z"))
(define rust-ordered-stream-0.2.0
  (crate-source "ordered-stream" "0.2.0"
                "0l0xxp697q7wiix1gnfn66xsss7fdhfivl2k7bvpjs4i3lgb18ls"))
(define rust-parking-2.2.1
  (crate-source "parking" "2.2.1"
                "1fnfgmzkfpjd69v4j9x737b1k8pnn054bvzcn5dm3pkgq595d3gk"))
(define rust-percent-encoding-2.3.2
  (crate-source "percent-encoding" "2.3.2"
                "083jv1ai930azvawz2khv7w73xh8mnylk7i578cifndjn5y64kwv"))
(define rust-phf-0.12.1
  (crate-source "phf" "0.12.1"
                "1dz85g1wshfca83mrq3va9rm9n8qcdjlpv1i3908y5zc9j4p6cli"))
(define rust-phf-shared-0.12.1
  (crate-source "phf_shared" "0.12.1"
                "10cr16wpmbjxd7w6k98sxw9yw3zxnzscybl9jzyq3digi045a006"))
(define rust-pin-project-lite-0.2.17
  (crate-source "pin-project-lite" "0.2.17"
                "1kfmwvs271si96zay4mm8887v5khw0c27jc9srw1a75ykvgj54x8"))
(define rust-piper-0.2.5
  (crate-source "piper" "0.2.5"
                "1hd3j94mw5dwc457gs9ssb2r5b9iipywndf5srqx7pj38jd4fdf8"))
(define rust-polling-3.11.0
  (crate-source "polling" "3.11.0"
                "0622qfbxi3gb0ly2c99n3xawp878fkrd1sl83hjdhisx11cly3jx"))
(define rust-portable-pty-0.9.0
  (crate-source "portable-pty" "0.9.0"
                "07k710gj2ixgp4r1lcfxvl2qfyvkjr52vb0zyna2sxfjnfi9d9dl"))
(define rust-proc-macro-crate-3.5.0
  (crate-source "proc-macro-crate" "3.5.0"
                "0kv1g1d1zjwxlgcaba2qlshzyy32j03xic8rskqlcr5mnblsfyz6"))
(define rust-r-efi-6.0.0
  (crate-source "r-efi" "6.0.0"
                "1gyrl2k5fyzj9k7kchg2n296z5881lg7070msabid09asp3wkp7q"))
(define rust-ring-0.17.14
  (crate-source "ring" "0.17.14"
                "1dw32gv19ccq4hsx3ribhpdzri1vnrlcfqb2vj41xn4l49n9ws54"))
(define rust-rustix-1.1.5
  (crate-source "rustix" "1.1.5"
                "17b2srw7rcqmrs1shj89g8i3r1447lihv7qrbxvp11j1psxgl7l9"))
(define rust-rustls-0.23.45
  (crate-source "rustls" "0.23.45"
                "0d6n90q52x5cjyxb6bwcnf9hwg6yb31cwr63rk8n5yfjqwqxfh8d"))
(define rust-rustls-pki-types-1.15.1
  (crate-source "rustls-pki-types" "1.15.1"
                "15hakk4pcvr5278cazgw9qf2r7gdg09rg5pivbyd3dbyih12aj9g"))
(define rust-rustls-webpki-0.103.15
  (crate-source "rustls-webpki" "0.103.15"
                "1hhanq3lz384v4nccacnjfwsyy99n3yc6m6iw8kljz8yicfwzhzk"))
(define rust-rustversion-1.0.23
  (crate-source "rustversion" "1.0.23"
                "07z2a843fs80fawwflj9jwn49k9b0bd0dhhbvy0ar69vaxd72m6g"))
(define rust-serde-repr-0.1.21
  (crate-source "serde_repr" "0.1.21"
                "01l987ghc17h1y9cf9xbzmcs77575mbrjf4ca2h70g15vqlicfwd"))
(define rust-serial2-0.2.38
  (crate-source "serial2" "0.2.38"
                "0c07302614zdvb7rfya82mzr7qywq15r4lqc9v71jfvr6ny0js5i"))
(define rust-shared-library-0.1.9
  (crate-source "shared_library" "0.1.9"
                "04fs37kdak051hm524a360978g58ayrcarjsbf54vqps5c7px7js"))
(define rust-shell-words-1.1.1
  (crate-source "shell-words" "1.1.1"
                "0xzd5p53xl0ndnk63r0by52rhdrh6pd37szfxszkg73zb6ffcvyw"))
(define rust-shlex-2.0.1
  (crate-source "shlex" "2.0.1"
                "1fjsll1cd7d2bcpdij9kd6w62rpbc7qqzvydvs021vsmr1cxvypq"))
(define rust-signal-hook-registry-1.4.8
  (crate-source "signal-hook-registry" "1.4.8"
                "06vc7pmnki6lmxar3z31gkyg9cw7py5x9g7px70gy2hil75nkny4"))
(define rust-siphasher-1.0.4
  (crate-source "siphasher" "1.0.4"
                "0mn28y43123jdpskdn6r9wibmn066f7h30zkkqn88bd6hj8zxx1k"))
(define rust-slab-0.4.12
  (crate-source "slab" "0.4.12"
                "1xcwik6s6zbd3lf51kkrcicdq2j4c1fw0yjdai2apy9467i0sy8c"))
(define rust-subtle-2.6.1
  (crate-source "subtle" "2.6.1"
                "14ijxaymghbl1p0wql9cib5zlwiina7kall6w7g89csprkgbvhhk"))
(define rust-syn-2.0.119
  (crate-source "syn" "2.0.119"
                "15vjy620l91a3q4n4f4gzhnflmdr6pnm38v2m6cpk86i8av32a47"))
(define rust-tempfile-3.27.0
  (crate-source "tempfile" "3.27.0"
                "1gblhnyfjsbg9wjg194n89wrzah7jy3yzgnyzhp56f3v9jd7wj9j"))
(define rust-thiserror-1.0.69
  (crate-source "thiserror" "1.0.69"
                "0lizjay08agcr5hs9yfzzj6axs53a2rgx070a1dsi3jpkcrzbamn"))
(define rust-thiserror-impl-1.0.69
  (crate-source "thiserror-impl" "1.0.69"
                "1h84fmn2nai41cxbhk6pqf46bxqq1b344v8yz089w1chzi76rvjg"))
(define rust-tokio-1.53.2
  (crate-source "tokio" "1.53.2"
                "0i202ksji8q2asvii0adzgi8m0z93z3j7apn62qfh8d6qzy92pz9"))
(define rust-tokio-macros-2.7.2
  (crate-source "tokio-macros" "2.7.2"
                "03kvy2r5gr4zccm4vdx8vvv3q69kbjc1b006rs11aibz74m3lxvq"))
(define rust-toml-edit-0.25.15+spec-1.1.0
  (crate-source "toml_edit" "0.25.15+spec-1.1.0"
                "0556lgzcvgfy16b8sxskr391s6cbfwnb0r4h5i4k6qw5lnaflh0k"))
(define rust-tracing-0.1.44
  (crate-source "tracing" "0.1.44"
                "006ilqkg1lmfdh3xhg3z762izfwmxcvz0w7m4qx2qajbz9i1drv3"))
(define rust-tracing-attributes-0.1.31
  (crate-source "tracing-attributes" "0.1.31"
                "1np8d77shfvz0n7camx2bsf1qw0zg331lra0hxb4cdwnxjjwz43l"))
(define rust-tracing-core-0.1.36
  (crate-source "tracing-core" "0.1.36"
                "16mpbz6p8vd6j7sf925k9k8wzvm9vdfsjbynbmaxxyq6v7wwm5yv"))
(define rust-uds-windows-1.2.1
  (crate-source "uds_windows" "1.2.1"
                "0vidqwwfgn8wyzvbxiqil787b4wyqjia50zpdbbjqx7n8wlgpxpj"))
(define rust-untrusted-0.9.0
  (crate-source "untrusted" "0.9.0"
                "1ha7ib98vkc538x0z60gfn0fc5whqdd85mb87dvisdcaifi6vjwf"))
(define rust-ureq-3.4.2
  (crate-source "ureq" "3.4.2"
                "1z6pmhf27s54f3sn2ja1rnqsrnbnjq2lr5xzpl5nwwmpx45w4yls"))
(define rust-ureq-proto-0.6.4
  (crate-source "ureq-proto" "0.6.4"
                "1gl32l71mdak562scwp66vpsjr894bbbvdk1ix2rwmnarird2vzq"))
(define rust-utf8-zero-0.8.1
  (crate-source "utf8-zero" "0.8.1"
                "0vjsmwd1k2wwlsn1phi7mrcjxn4bv8fzk24caxyaw2slr51s1h5q"))
(define rust-uuid-1.27.0
  (crate-source "uuid" "1.27.0"
                "16h5h6bf5ybh1lj97lcdl41g7fqbiczpavpsb0zf3b63p4v7s9wp"))
(define rust-wasi-0.11.1+wasi-snapshot-preview1
  (crate-source "wasi" "0.11.1+wasi-snapshot-preview1"
                "0jx49r7nbkbhyfrfyhz0bm4817yrnxgd3jiwwwfv0zl439jyrwyc"))
(define rust-wasm-bindgen-0.2.129
  (crate-source "wasm-bindgen" "0.2.129"
                "02flhqld01jqb6vbfyx1gb8s78g1pnq2164daxad93y6mhrlzdcv"))
(define rust-wasm-bindgen-macro-0.2.129
  (crate-source "wasm-bindgen-macro" "0.2.129"
                "0dc5xq09sy1v9ns1fhb0cnyqz5p1wcjjvkdmxskj9qhnbg1x0a9f"))
(define rust-wasm-bindgen-macro-support-0.2.129
  (crate-source "wasm-bindgen-macro-support" "0.2.129"
                "1dx6w90f14avmhri7ss9lyz03060g6475r4axy3bm7biqf5ill3g"))
(define rust-wasm-bindgen-shared-0.2.129
  (crate-source "wasm-bindgen-shared" "0.2.129"
                "1ilmp5d3sl8lrq9djhcs90gk66yvk8mgwk4sfrvpvkd75b2wkw13"))
(define rust-webpki-roots-1.0.9
  (crate-source "webpki-roots" "1.0.9"
                "0apja04243wz3vi26pqjg4sq8cqaac66prj490sgb1crlc4rvkbx"))
(define rust-winapi-0.3.9
  (crate-source "winapi" "0.3.9"
                "06gl025x418lchw1wxj64ycr7gha83m44cjr5sarhynd9xkrm0sw"))
(define rust-winapi-i686-pc-windows-gnu-0.4.0
  (crate-source "winapi-i686-pc-windows-gnu" "0.4.0"
                "1dmpa6mvcvzz16zg6d5vrfy4bxgg541wxrcip7cnshi06v38ffxc"))
(define rust-winapi-x86-64-pc-windows-gnu-0.4.0
  (crate-source "winapi-x86_64-pc-windows-gnu" "0.4.0"
                "0gqq64czqb64kskjryj8isp62m2sgvx25yyj3kpc2myh85w24bki"))
(define rust-windows-core-0.62.2
  (crate-source "windows-core" "0.62.2"
                "1swxpv1a8qvn3bkxv8cn663238h2jccq35ff3nsj61jdsca3ms5q"))
(define rust-windows-implement-0.60.2
  (crate-source "windows-implement" "0.60.2"
                "1psxhmklzcf3wjs4b8qb42qb6znvc142cb5pa74rsyxm1822wgh5"))
(define rust-windows-interface-0.59.3
  (crate-source "windows-interface" "0.59.3"
                "0n73cwrn4247d0axrk7gjp08p34x1723483jxjxjdfkh4m56qc9z"))
(define rust-windows-link-0.2.1
  (crate-source "windows-link" "0.2.1"
                "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h"))
(define rust-windows-result-0.4.1
  (crate-source "windows-result" "0.4.1"
                "1d9yhmrmmfqh56zlj751s5wfm9a2aa7az9rd7nn5027nxa4zm0bp"))
(define rust-windows-strings-0.5.1
  (crate-source "windows-strings" "0.5.1"
                "14bhng9jqv4fyl7lqjz3az7vzh8pw0w4am49fsqgcz67d67x0dvq"))
(define rust-windows-sys-0.52.0
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "windows-sys" "0.52.0"
                "0gd3v4ji88490zgb6b5mq5zgbvwv7zx1ibn8v3x83rwcdbryaar8"))
(define rust-windows-sys-0.61.2
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "windows-sys" "0.61.2"
                "1z7k3y9b6b5h52kid57lvmvm05362zv1v8w0gc7xyv5xphlp44xf"))
(define rust-windows-targets-0.52.6
  (crate-source "windows-targets" "0.52.6"
                "0wwrx625nwlfp7k93r2rra568gad1mwd888h1jwnl0vfg5r4ywlv"))
(define rust-windows-aarch64-gnullvm-0.52.6
  (crate-source "windows_aarch64_gnullvm" "0.52.6"
                "1lrcq38cr2arvmz19v32qaggvj8bh1640mdm9c2fr877h0hn591j"))
(define rust-windows-aarch64-msvc-0.52.6
  (crate-source "windows_aarch64_msvc" "0.52.6"
                "0sfl0nysnz32yyfh773hpi49b1q700ah6y7sacmjbqjjn5xjmv09"))
(define rust-windows-i686-gnu-0.52.6
  (crate-source "windows_i686_gnu" "0.52.6"
                "02zspglbykh1jh9pi7gn8g1f97jh1rrccni9ivmrfbl0mgamm6wf"))
(define rust-windows-i686-gnullvm-0.52.6
  (crate-source "windows_i686_gnullvm" "0.52.6"
                "0rpdx1537mw6slcpqa0rm3qixmsb79nbhqy5fsm3q2q9ik9m5vhf"))
(define rust-windows-i686-msvc-0.52.6
  (crate-source "windows_i686_msvc" "0.52.6"
                "0rkcqmp4zzmfvrrrx01260q3xkpzi6fzi2x2pgdcdry50ny4h294"))
(define rust-windows-x86-64-gnu-0.52.6
  (crate-source "windows_x86_64_gnu" "0.52.6"
                "0y0sifqcb56a56mvn7xjgs8g43p33mfqkd8wj1yhrgxzma05qyhl"))
(define rust-windows-x86-64-gnullvm-0.52.6
  (crate-source "windows_x86_64_gnullvm" "0.52.6"
                "03gda7zjx1qh8k9nnlgb7m3w3s1xkysg55hkd1wjch8pqhyv5m94"))
(define rust-windows-x86-64-msvc-0.52.6
  (crate-source "windows_x86_64_msvc" "0.52.6"
                "1v7rb5cibyzx8vak29pdrk8nx9hycsjs4w0jgms08qk49jl6v7sq"))
(define rust-winreg-0.10.1
  (crate-source "winreg" "0.10.1"
                "17c6h02z88ijjba02bnxi5k94q5cz490nf3njh9yypf8fbig9l40"))
(define rust-zbus-5.19.0
  (crate-source "zbus" "5.19.0"
                "01sram5sgwsg3x8mghx77cjbsfa2c10mar7fnzj23d2w0xybxd2x"))
(define rust-zbus-macros-5.19.0
  (crate-source "zbus_macros" "5.19.0"
                "0h4gr26kyhdyn503rgg8h44sjxm8d6n8qbzpd0cdzrmd15fn7419"))
(define rust-zbus-names-4.3.4
  (crate-source "zbus_names" "4.3.4"
                "0kk250s3x1fxpz9fvhdr64ydbacpn8ah23hy021yhlzzlfs8igyq"))
(define rust-zcheapstr-1.1.0
  (crate-source "zcheapstr" "1.1.0"
                "0wwlv70bi2rydvvzfq249q6i51mjx85c4m2wxcx1hra5c18yrbyi"))
(define rust-zeroize-1.9.0
  (crate-source "zeroize" "1.9.0"
                "0kpnij2v1ig6g2mhc0bnci0lrdfdhiq40afbc0fahajqc9jiag71"))
(define rust-zvariant-5.15.0
  (crate-source "zvariant" "5.15.0"
                "0iwihslxshfhalihp6kv7xz7nbv1p3b9sl97hi2izpbcrhklrly1"))
(define rust-zvariant-derive-5.15.0
  (crate-source "zvariant_derive" "5.15.0"
                "15y4z1rkcpvrz7dv7j2rfv8wiq6i8nzifj9pgw6dnlj3kgk5ahc6"))
(define rust-zvariant-utils-4.2.0
  (crate-source "zvariant_utils" "4.2.0"
                "18q80094ci64myzvcp0g2l3c6mnx7b3hsii8lfabc853c51jkl5s"))

(define rust-pkg-config-0.3.34
  (crate-source "pkg-config" "0.3.34"
                "0j05h08nzg0q8rf6lzw7nry0b7kn7x97vc9n4hwrl52fqzxn9d7n"))

(define rust-quick-xml-0.41.0
  (crate-source "quick-xml" "0.41.0"
                "1h9y8zry34r3mxfd5vqfj50vvvzvri4kzbx5d657jkqjalg4aq76"))

(define rust-smallvec-1.16.2
  (crate-source "smallvec" "1.16.2"
                "13iai5hhwyp8z0pbn8r11q4j5956jaxhcbvvf2drm17f1q7myfgr"))

(define rust-wayland-backend-0.3.17
  (crate-source "wayland-backend" "0.3.17"
                "0y50cw56f09cdcsinbbl94naz91xf7iqaj87s4f7py6zmm71pa9q"))

(define rust-wayland-client-0.31.15
  (crate-source "wayland-client" "0.31.15"
                "0ww0d0r6rn2h0sn8ma1f7zvxj40l6930p07j044nvmqshq7nmhz3"))

(define rust-wayland-protocols-0.32.13
  (crate-source "wayland-protocols" "0.32.13"
                "1dn4injzx1lnmacnhl3q60m743lvshxmmy0aabb2xaixvq9wil13"))

(define rust-wayland-protocols-wlr-0.3.9
  (crate-source "wayland-protocols-wlr" "0.3.9"
                "1v3qbg18vsb3i62c6042xhjm7dcflmylzjlhl0w9kks3xmilkngg"))

(define rust-wayland-scanner-0.31.11
  (crate-source "wayland-scanner" "0.31.11"
                "1h0al3271l2w124sxlh77s1kmjg0z24ns2mk1vbnfars3d3313ik"))

(define rust-wayland-sys-0.31.11
  ;; TODO REVIEW: Check bundled sources.
  (crate-source "wayland-sys" "0.31.11"
                "1gp3hlkxx13i55lyyi794vnw9a780z3skx0xhj71zr69xwzv5snq"))

(define nosd-theme-cargo-inputs
  (list rust-adler2-2.0.1
        rust-cfg-if-1.0.5
        rust-crc32fast-1.5.2
        rust-equivalent-1.0.2
        rust-flate2-1.1.2
        rust-hashbrown-0.17.1
        rust-indexmap-2.14.2
        rust-itoa-1.0.18
        rust-memchr-2.8.3
        rust-miniz-oxide-0.8.9
        rust-proc-macro2-1.0.107
        rust-quote-1.0.47
        rust-serde-1.0.229
        rust-serde-core-1.0.229
        rust-serde-derive-1.0.229
        rust-serde-json-1.0.151
        rust-serde-spanned-1.1.1
        rust-syn-3.0.6
        rust-toml-1.1.6+spec-1.1.0
        rust-toml-datetime-1.1.1+spec-1.1.0
        rust-toml-parser-1.1.3+spec-1.1.0
        rust-toml-writer-1.1.2+spec-1.1.0
        rust-unicode-ident-1.0.26
        rust-winnow-1.0.4
        rust-zmij-1.0.23))

(define nosd-helpers-cargo-inputs
  (list rust-adler2-2.0.1
        rust-android-system-properties-0.1.6
        rust-anyhow-1.0.104
        rust-async-broadcast-0.7.2
        rust-async-channel-2.5.0
        rust-async-executor-1.14.0
        rust-async-io-2.6.0
        rust-async-lock-3.4.2
        rust-async-process-2.5.0
        rust-async-recursion-1.2.0
        rust-async-signal-0.2.14
        rust-async-task-4.7.1
        rust-async-trait-0.1.92
        rust-atomic-waker-1.1.2
        rust-autocfg-1.5.1
        rust-base64-0.23.1
        rust-bitflags-1.3.2
        rust-bitflags-2.13.2
        rust-blocking-1.7.0
        rust-bumpalo-3.20.3
        rust-bytes-1.12.1
        rust-cc-1.6.0
        rust-cfg-if-1.0.5
        rust-cfg-aliases-0.1.1
        rust-chrono-0.4.45
        rust-chrono-tz-0.10.4
        rust-concurrent-queue-2.5.0
        rust-core-foundation-sys-0.8.7
        rust-crc32fast-1.5.2
        rust-crossbeam-utils-0.8.23
        rust-downcast-rs-1.2.1
        rust-endi-1.1.1
        rust-enumflags2-0.7.12
        rust-enumflags2-derive-0.7.12
        rust-equivalent-1.0.2
        rust-errno-0.3.14
        rust-event-listener-5.4.2
        rust-event-listener-strategy-0.5.4
        rust-fastrand-2.5.0
        rust-filedescriptor-0.8.3
        rust-find-msvc-tools-0.1.14
        rust-flate2-1.1.10
        rust-futures-core-0.3.34
        rust-futures-io-0.3.34
        rust-futures-lite-2.6.1
        rust-futures-task-0.3.34
        rust-futures-util-0.3.34
        rust-getrandom-0.2.17
        rust-getrandom-0.4.3
        rust-hashbrown-0.17.1
        rust-hermit-abi-0.5.3
        rust-hex-0.4.3
        rust-http-1.5.0
        rust-httparse-1.10.1
        rust-iana-time-zone-0.1.65
        rust-iana-time-zone-haiku-0.1.2
        rust-indexmap-2.14.2
        rust-itoa-1.0.18
        rust-js-sys-0.3.106
        rust-lazy-static-1.5.1
        rust-libc-0.2.190
        rust-linux-raw-sys-0.12.1
        rust-log-0.4.34
        rust-memchr-2.8.3
        rust-memoffset-0.9.1
        rust-miniz-oxide-0.9.1
        rust-nix-0.28.0
        rust-num-traits-0.2.19
        rust-once-cell-1.21.4
        rust-ordered-stream-0.2.0
        rust-parking-2.2.1
        rust-percent-encoding-2.3.2
        rust-phf-0.12.1
        rust-phf-shared-0.12.1
        rust-pin-project-lite-0.2.17
        rust-piper-0.2.5
        rust-pkg-config-0.3.34
        rust-polling-3.11.0
        rust-portable-pty-0.9.0
        rust-proc-macro-crate-3.5.0
        rust-proc-macro2-1.0.107
        rust-quick-xml-0.41.0
        rust-quote-1.0.47
        rust-r-efi-6.0.0
        rust-ring-0.17.14
        rust-rustix-1.1.5
        rust-rustls-0.23.45
        rust-rustls-pki-types-1.15.1
        rust-rustls-webpki-0.103.15
        rust-rustversion-1.0.23
        rust-serde-1.0.229
        rust-serde-core-1.0.229
        rust-serde-derive-1.0.229
        rust-serde-json-1.0.151
        rust-serde-repr-0.1.21
        rust-serial2-0.2.38
        rust-shared-library-0.1.9
        rust-shell-words-1.1.1
        rust-shlex-2.0.1
        rust-signal-hook-registry-1.4.8
        rust-simd-adler32-0.3.10
        rust-siphasher-1.0.4
        rust-slab-0.4.12
        rust-smallvec-1.16.2
        rust-subtle-2.6.1
        rust-syn-2.0.119
        rust-syn-3.0.6
        rust-tempfile-3.27.0
        rust-thiserror-1.0.69
        rust-thiserror-impl-1.0.69
        rust-tokio-1.53.2
        rust-tokio-macros-2.7.2
        rust-toml-datetime-1.1.1+spec-1.1.0
        rust-toml-edit-0.25.15+spec-1.1.0
        rust-toml-parser-1.1.3+spec-1.1.0
        rust-tracing-0.1.44
        rust-tracing-attributes-0.1.31
        rust-tracing-core-0.1.36
        rust-uds-windows-1.2.1
        rust-unicode-ident-1.0.26
        rust-untrusted-0.9.0
        rust-ureq-3.4.2
        rust-ureq-proto-0.6.4
        rust-utf8-zero-0.8.1
        rust-uuid-1.27.0
        rust-wasi-0.11.1+wasi-snapshot-preview1
        rust-wasm-bindgen-0.2.129
        rust-wasm-bindgen-macro-0.2.129
        rust-wasm-bindgen-macro-support-0.2.129
        rust-wasm-bindgen-shared-0.2.129
        rust-wayland-backend-0.3.17
        rust-wayland-client-0.31.15
        rust-wayland-protocols-0.32.13
        rust-wayland-protocols-wlr-0.3.9
        rust-wayland-scanner-0.31.11
        rust-wayland-sys-0.31.11
        rust-webpki-roots-1.0.9
        rust-winapi-0.3.9
        rust-winapi-i686-pc-windows-gnu-0.4.0
        rust-winapi-x86-64-pc-windows-gnu-0.4.0
        rust-windows-core-0.62.2
        rust-windows-implement-0.60.2
        rust-windows-interface-0.59.3
        rust-windows-link-0.2.1
        rust-windows-result-0.4.1
        rust-windows-strings-0.5.1
        rust-windows-sys-0.52.0
        rust-windows-sys-0.61.2
        rust-windows-targets-0.52.6
        rust-windows-aarch64-gnullvm-0.52.6
        rust-windows-aarch64-msvc-0.52.6
        rust-windows-i686-gnu-0.52.6
        rust-windows-i686-gnullvm-0.52.6
        rust-windows-i686-msvc-0.52.6
        rust-windows-x86-64-gnu-0.52.6
        rust-windows-x86-64-gnullvm-0.52.6
        rust-windows-x86-64-msvc-0.52.6
        rust-winnow-1.0.4
        rust-winreg-0.10.1
        rust-zbus-5.19.0
        rust-zbus-macros-5.19.0
        rust-zbus-names-4.3.4
        rust-zcheapstr-1.1.0
        rust-zeroize-1.9.0
        rust-zlib-rs-0.6.8
        rust-zmij-1.0.23
        rust-zvariant-5.15.0
        rust-zvariant-derive-5.15.0
        rust-zvariant-utils-4.2.0))
