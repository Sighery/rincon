+++
date = "2026-11-18T00:00:00+00:00"
draft = false
title = "Exploring post-quantum cryptography support in sops-nix"
summary = "The documentation is a bit lacking, but turns out Age, the underlying encryption tool used by sops-nix, supports post-quantum cryptography"
series = ["NixOS", "Secrets management", "Sops", "Age", "Post-quantum"]
+++


In a [previous article][Keeping NixOS secrets, secret] I wrote about my
secrets setup, separating them and sensitive values into a private flake. One
of the reasons for this is that I worry about a potential future where quantum
computers develop enough to break our current algorithms.

Someone contacted me after I wrote that article, and we got to talking about
post-quantum cryptography support in [sops-nix]. Turns out, even though
sops-nix makes no mention of post-quantum cryptography in its documentation,
it uses [Age] as the underlying encryption tool, which can generate
post-quantum keys.


## Post-quantum Age keys

Introduced in [Age v1.3.0 in December 2025][Age v1.3.0], creating PQ
(post-quantum) keys is quite easy:

```sh { caption="Yes, PQ keys are that long" }
$ age-keygen -pq
# created: 2026-11-11T09:31:21+01:00
# public key: age1pq1vpdeg8eqqxzgkaexkfezt2axffnvzwqhs3v6s679k7sh6kpcmtnqlt8mcrvtk3wzgftfljn225sjakgfy9zzq6sjf937yz6ycpdqxvngnlxnjxepap9zau788pg2ez69jvs4z6gleqem2kt86w93pfvnecs2kcj4l9hvuarxtp4cjhwv4shshx5c2alsrxtkdrj2kmdy3vu6sryppy4ndmz6pegn6xjtzl0qqkj5zawn0t9qsttmadg2ct7lcvc8fydxg2gga7kxvmjuy9shksfxqft38r98l49ghm8scgkn4g7xcaq64vpfn3ny7zgnq9k6gc7tw95ne32w2z9fvlpxjdayy8x02u3n6wurptyxsercffj7jaj56r9saafzfsujuza98lemzjyrks27sdn4rsnyy2fux580q3mzz7gyv345yekgdlkmzch64zq50zzzzryuu7rkjfwcz37jzq4s5s0frcccv89uu9wht3fphp9pzac8tz3auyvqqstq3qhxxrxgs79sqfd4gyt66uvppt2z2a0k6jga4sfehwetqrc3sju5wnm4m9d325fp0wy6g32engscx0fvyk99q7evd4f3l9qf8l84psajdrr09szerrd59x8shs2e8su9hqlp823evlr9598tqmc5ns9l0vy2fseawpj42wtewyl9sq58uwx4vvsstys429dgt3xk5g45tga6t5j7f7qz4auyk0f3z05mqhrth77xne3gam8mfnkhwggrg3a62248mxmytdus92eg4wp3pyx3deuuy7smnu0swp45xqpd4svyuunt6f56373cvspyklmdtsex8lzx8dc92al8se6xfwwpwcd23k27xdm65ce648ut2eunweeaw4kq456p7wqnc6uzwxu3w6v4c6qm9w4f6cfyds48hffm5ulgc479fh5vguqvtazgq5f2t2dsl5vv9c3qpqlf38y4rqgtzl93z350wycfsp2ceguxqf6rqp65sdfsemfut4lyctsscldzxz9egz3w042vy4ukc939jh4ys6x2xc7dp0pe8g5zr96dsgjmyqlmjf30cjf4rqnzpm2hf95kavkym7es6g5zunf3q2xvw789qdx27eth8328ccykjwtgvtcwpym58jfywt4x4zcn57q75ual832kh7q0vefe9ccv0acsg0p87x4emafw5sdfcn8vfh20d39xn0zsnemtl2r3vd7tva0vtwswj2dlg39s8mc9x5d808r83v9t4yglfx3afw94fuuc8amq0xlxrxhk6eskwrrfy3g8nkszfs5fg6su39y6v7ypkwd9hy8twr57mw4jksgfxkmeevt3rzqeqlv6gp6segf6mpm4v3aykcfyftl28yapxzztasexdm489yxxkaym0flcmwvwnq62hhexzyxmgvekwercu92jzjrnznsnhwuqfrg5rsfynv5w24tr52q9c3pq5xx2ly8fh7v0qrqn2m8np0r7z5pzt8pc8ks7l0xtlr72gvzm5l6dm9deq54fctw97k85ftqk4wq2xphh8q2jzyr86yl3zclzwpt523dk96u4artyxpcfg8rlw0lz2sfjtza4053ty2arknt5zdyx7hx2qlr5403xyjf54s02jaju525vxg22cnzskgljvqc29yfhdn9jlj6tkumhgwpzprylgdhppny46gfknpecyeug2l5rct0753qvtwxrzquucw0qepwecv9uq3266an6vfp4cj6uccc6jdd0c9jtn9zx64ds0vry2hwvwdkvw66gnly2pfenls5tsegldjju2ays6vnzef444y0zvaeh2a0h5q9rw5wzp8pzpa5r75mahavexcs2pzlfmqu2uvftuy69g96ftflz6n4xm6dq2k80jzv0430chrwye4rwf249pya8aj3cj6uyj6skkc2y9ulehydv
AGE-SECRET-KEY-PQ-1J9R2JKLMMFTDW93VA79MZ284W9MP4FVMLF293JSEKJGU5USVXK9SPW3XG5
```


## Are my secrets post-quantum resistant?

An easy way to determine if your secrets are using post-quantum Age keys is to
look at the prefixes. For private keys, it should start with
`AGE-SECRET-KEY-PQ-1`. For public keys, `age1pq1`.

Another thing to keep in mind is the recipients list for a given secret. Take
this example:

```yaml { file=".sops.yaml" }
keys:
  - &host_pq age1pq1mvme3zd4zeepyne9y88wq447w6t5aukhgh8kqd7l0qd48xzymk44rz92fgrvez76z7d2awsh5acmur7t2lc3y746sawuh5ggmmp28rkffk5cgykrwhyt0x3480p4kw5qvuc32d7zq5zhcn9ryuccwz0y3q9rnda2tzrdhyc9dhrvdth6nu7exwyt72xnzsqgpsvvnch83tkh98rrwd452snvugjxdk0qtaredrd6as47z3fmzfqfkhgy3suuxgfzarrwz4yfky6cecltr2528xg3ffrfuc9f03jxa2m9zlapz4ud03znxuxdntqj4llxykkfhjdfsa43vmzyqutuxyfqdssmvuskerrhg6mn5kcffvhrww5frgsmq4wt2e6f8t35tl3kd304czuw4prhapug02y292xuekmhvtca2ahm3kzy0lajc30vjlcek90uz9k9lgfff592mzuvw7z45y7kf08fwxdteqpqhtgzs3khzvl2l3rn2fdwywm8ep035n0yxawszcucdy4u9le92hvzxlpwdnvjkkekj26566uqjwx9rxd2v6ncfpl8k0xpegqp9d85pvtr4fwlk6mxzsfw8kav6y4z0f4uykjc3wrph5fxelt2y8nyz636f03zz3udgjrgk5rfxp5jd8nqe8nw0s39xef05tsk2vvpxw0n5jsh2utnhj42ksgcpyvm50ayvnwujxzavutlcxgh52t3wdl493jcjpqryx24r4vstf88g62w83tk5wwjjnrfh35y3d0znhcns22jfpawk4u263z62njqwaavjysev40w4df2fnehhz3kewpeppe2eg3jmj5uncvcvk78ftcnf9ur7fgg09uv8k2mg5z8nd5evdmz6anmxjf3a0f2fasurwl8g2rrmfqh3wq0sdvtjrvmhqpftqpvq5sjanx0mnjnqxhc53nvcuwc2kftj32k5u6g2hjhfck2cldplfphspgy9ay6zgezxucsg4lqgzneqd67tjfshtce94hhr0sgdwkcvur2a94zw6jcd3qk3j93d28tfxff8faq676r2upd4z9g98rgewvrttrchashzz2yqk9c3txpr9sjvurmgzwk2vznpdg7ur8crkdwud6crvs2x5r62e5hxpfxmfqrklr9jzt49543z4j3v7jgst9tfwmvae8g4277rp73vfrgljscv2tzawzgev9gzy074xznl9nyp4vz3uk9e4re9nq0ss8rhzsmwc640l3sc7d4gvcue2lmq9rpaddcaqdndes6je7h9dh89nptpytf5764nfdxdpwrgfk5cergz0fgkwxx8mleygrmqmratu37rac9yugfqjjv5zg00j3kzvuaqw4n265204q2nfzpsgnnfw3263y2k6u8x4y3scqs8y3kggwvayehchlgdad5rvp5q3v9rqza3ja6u3mj8cpxz0eyvs6slgn0harz5pqr9jhjcnjy0pk70g34y2js9xc59zcx2pyf39t0ghq4fzum7yh6egt4czvkysz2snzjw8e6amkvfjd2qhllvg95v4nzca2qjtsq5hzrx4gzwexylpt9az9cc8mnfsajt8k7w3yerkaz2ppftmeynee4q76cpqptukte2unpacmk8qvkjva7nf0xuxclappnscrs3pmdcmzsqu6rvep2zlgzjcg3grems23xj3jmxcu00m7pqnh3chsvz7es62qr4r9ey65cyw6hdasvvy7efpwdpx9tetcg8mc3ynpf3t9tmzpyywma073rqs42c2sljw6f7dee70p7wvn4fexteq4whdhrweqk65nrdqmh0mzgq606gnv26y0nc54qzu0z0n0j6vyctc8mnpu686cflsat5maje8anuma0l0gaakg9u79ddu4ugm023pspf7c3udh2847rp3ajkcrvzj7a45tgkejszqcnt359
  - &host_classic age19tt5uzx22g05wfwzmqaksl4f5lpphmu9hzfgp82y4zn2vv6w5uwqej8v23


creation_rules:
  - path_regex: host_mixed.yaml
    key_groups:
      - age:
        - *host_pq
        - *host_classic
```

Here the `host_mixed.yaml` file—which contains the secrets and will be
encrypted—has two recipients: a PQ Age key and a classic Age key. This
effectively makes it **not** post-quantum resistant. An attacker would need
only to break the classic Age key to decrypt all the secrets, completely
bypassing the `host_pq` post-quantum Age key.

Therefore a post-quantum resistant secrets setup **must** use PQ Age keys, and
**only** PQ Age keys.


## What about SSH keys?

SSH keys are likewise not post-quantum safe. While
[OpenSSH has started hardening against a probable quantum future][OpenSSH PQ],
it only covers the key exchange algorithms so far:

> The entire privacy of an SSH connection depends on cryptographic key
> agreement. If an attacker can break the key agreement then they are able to
> decrypt and view the entire session. The attacker need not perform this
> attack in real time; they may collect encrypted SSH sessions now and then
> decrypt them later once they have access to a quantum computer. This is
> referred to as a "store now, decrypt later" attack (also as "harvest now,
> decrypt later").

The commonly used signature algorithms are not PQ resistant. This is also
covered in the linked page:

> **What about signature algorithms? You said they were at risk too**  
> Yes, most currently-used signature algorithms (including RSA and ECDSA) can
> be broken by a quantum computer. However, there is no risk to existing
> traffic in this situation (i.e. there is no analogous "store now, decrypt
> later"). The only urgency for signature algorithms is ensuring that all
> classical signature keys are retired in advance of
> cryptographically-relevant computers becoming a reality. OpenSSH will add
> support for post-quantum signature algorithms in the future.

For SSH this is fine. Like they point out, traffic is handled by PQ algorithms
already. Meanwhile in sops-nix—and Agenix—there is no key exchange step;
our signature algorithms are used directly to share the secrets. Therefore any
encrypted secrets could be harvested now and decrypted in the future.


## Side quest: SSH recipients

If you set up your secrets with sops-nix in the last few years, chances are
you are using SSH keys. To be precise, you are likely using SSH-derived Age
keys; this is what [sops-nix documents][sops-nix usage]. The tool [ssh-to-age]
is used for the conversion.

```sh { attr="From sops-nix README: \"3. Get a public key for your target machine\""  attrlink="https://github.com/Mic92/sops-nix/blob/fe7b4228405aeac2ce7192c2049a6e2bc8637082/README.md#usage-example" }
$ nix-shell -p ssh-to-age --run 'ssh-keyscan example.com | ssh-to-age'
age1rgffpespcyjn0d8jglk7km9kfrfhdyev6camd3rck6pn8y47ze4sug23v3
$ nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
age1rgffpespcyjn0d8jglk7km9kfrfhdyev6camd3rck6pn8y47ze4sug23v3
```

This is however not strictly necessary. Age supports encrypting
[to SSH recipients directly][Age SSH recipients].
[As does Sops][Sops Age SSH recipients]. The only missing link in the chain
was sops-nix [until very recently][sops-nix SSH recipients PR]. But now that
SSH recipients are supported, we don't need an extra step converting SSH keys
into Age keys:

```yaml { file=".sops.yaml" attr="From my sops-nix PQ exploration project" attrlink="https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/.sops.yaml" }
keys:
  - &host_ssh ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJO6w8KI70f22aYECLsvds6fsYPQWrsyYpzlwZIArabv

creation_rules:
  - path_regex: host_ssh.yaml
    key_groups:
      - age:
        - *host_ssh
```

```nix { file="configuration.nix" attr="From my sops-nix PQ exploration project" attrlink="https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/secrets-ssh.nix" }
{ ... }:

{
  sops.defaultSopsFile = ./host_ssh.yaml;
  sops.age.sshKeyFile = "/etc/ssh/ssh_ed25519_key";

  sops.secrets."my_custom_secret" = { };
}
```

## Playing around with secrets

Another great thing about NixOS is that the same configuration used to deploy
your machine
[can be used to deploy a virtual machine][NixOS virtual machines].

So instead of messing around with my NixOS systems, I could create new bare
NixOS systems, having just enough configuration to use sops-nix with some
secrets that run on a VM, making them easily shareable.
[That is exactly what I did][sops-nix-pq-exploration].

### The three systems

There are three NixOS systems, each one using a different recipient target.

```yaml { file=".sops.yaml" attr="From my sops-nix PQ exploration project" attrlink="https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/.sops.yaml" }
keys:
  - &admin_pq age1pq1mvnumezvvwsmyql7agyle335fv5y3mthfkwm5nr64y82elqlxazc6hnxq8n64980xk6a0ue8lrp8d269npjc8zmf99j6jaysjep5ug88n2wyvqtcz3034gd9u2tkv4cfvfcevgz22edzs6c06ldrmseqte5w5jnstytjw9mw8rp2klux98qav222mw90549vp6pgwkhgz8jlxfdj5skzqwdxdpp2ga8e2w0ry3l73gmnuut6gp2s4gy6xq56wlm4zjcdluzy3ljm65axr0rnpgxpgfgus7mujwmkypjj8l8sy57ty56fyjuhh72r5f96326t9nevhzrayzefuespakr9pqfcxvdm898frgpggx38a2ah8ttew5kscygd0mqfdhyp2dufj5c8z8yr4gsxsaz3j8r3gzt5vadpnt3v8pl4k2yxn5j6lq7xdk7nnv2cywml5ezttny6pk5y0vzxgkddt97lcpgjklc65qzegcjn8nly4xra8xvs9a66hrtceeqs54lgs2cl0gv6erm6s5gv0kxezas2z6wyuuq689f9ecq82pzlwz0yqkkax3ny6lee0rm3rqzuh2rpqcw0l423quqzf3dfdwxff2f26cdlptyp6tjta726z62r4waz0drchkqj93rp5q4fp2d6g4awjfzdvwuhnvuza78xerwgj86vljsht64rrs5cxylqqtcgrfrj68qssupv80u85tl4vh3gvlq05kgh3w2f4acx58wcyktfcx49z8rvacdhgxfyfpk5svmu30prtxwdvp3h5l6u8y9cvy4ac06xsyrhvs9k6nncrcfth6sqpfq6zq6sj4ys8g55czajrxle5s7s7pmnf7224wf5ve7nsp685mq4lw5ah6mer6qux9znz9c4t8m065arl3uxf72ngnxrkrjjzknn0jl9q3geyhz3f5wzevwxvy0wxgyqzgyc62uer5p95k86v8ge89u3xtreusmsudm6yukmk0zkk66jnatk9ccnqyurtext0qz5aweh8y64hs3fs4zpsq4es9xf5f8rusujq7fn0dxh3fqttpaymy9sjwp8fmuxzft3xxgvzdjyhfqtrupue83quleeysdwvvr9p93slgra8hqelpdsdq7vsz0ejc984jpmf09k6qzdcthcvpkn6q5k0zxfhzj25c76qf38cfw5tp3966nn6cgsntz5fxmfyrny4gwgwdfv7j3m86upyz5jqupjz9zv7fqjmqysg3g9nwat9qx2yzvalugh4mtkqf765u8mnvr07xlquy7x6dkxe8w5wemvp0s77ghzx360r6dt6qp3tyvgd8urupjgffyukt6n0ehkrslr2z8n4qf636338jg46u7yy97wvjwk5vngzrpudpuq0gm44etewddvv27ga8ztzrshrghn9af9gg8mc6dk6del8n9r48lg0t4aguxru9ffcxdrx55rsp0svuldys789jjs4canksme92sj396s80jtk5wuxprz833j98kv5e2c4f5vjqm9ee3s8ku4u06m30zmzpex7v4v895mxv5nljuqxpnnjp68sfr7899fqmavmv4zxhcprflt7csx7369xse4ew5m8qq3sldf53mahzeqajsywg3j8r7yq727g3jm6gt9ygdyp626tjewhwv5ws6pn9y784ngrlq9g2jwyu28yvsdvlrrfv4xm7qp5kzz89eey5d3q2g3ngchvw4e3ujvq94zhnq07vaar4me48a2fh76q0na25gzz2p2hzgzn3853pser0jx55tmdf5x945k5mmzj4s6ye5d75gj7nyga0mtm9gkytqfgy5y57mt8jfqjem42du965mg4uv0qnufer3ppfg2nl7pnnuv4epkuhvhd999hpz7z0ydq04ynfktzpg6w70eflgn49tq2jjwa79s6dddq9fg8cd0cykl
  - &host_pq age1pq1mvme3zd4zeepyne9y88wq447w6t5aukhgh8kqd7l0qd48xzymk44rz92fgrvez76z7d2awsh5acmur7t2lc3y746sawuh5ggmmp28rkffk5cgykrwhyt0x3480p4kw5qvuc32d7zq5zhcn9ryuccwz0y3q9rnda2tzrdhyc9dhrvdth6nu7exwyt72xnzsqgpsvvnch83tkh98rrwd452snvugjxdk0qtaredrd6as47z3fmzfqfkhgy3suuxgfzarrwz4yfky6cecltr2528xg3ffrfuc9f03jxa2m9zlapz4ud03znxuxdntqj4llxykkfhjdfsa43vmzyqutuxyfqdssmvuskerrhg6mn5kcffvhrww5frgsmq4wt2e6f8t35tl3kd304czuw4prhapug02y292xuekmhvtca2ahm3kzy0lajc30vjlcek90uz9k9lgfff592mzuvw7z45y7kf08fwxdteqpqhtgzs3khzvl2l3rn2fdwywm8ep035n0yxawszcucdy4u9le92hvzxlpwdnvjkkekj26566uqjwx9rxd2v6ncfpl8k0xpegqp9d85pvtr4fwlk6mxzsfw8kav6y4z0f4uykjc3wrph5fxelt2y8nyz636f03zz3udgjrgk5rfxp5jd8nqe8nw0s39xef05tsk2vvpxw0n5jsh2utnhj42ksgcpyvm50ayvnwujxzavutlcxgh52t3wdl493jcjpqryx24r4vstf88g62w83tk5wwjjnrfh35y3d0znhcns22jfpawk4u263z62njqwaavjysev40w4df2fnehhz3kewpeppe2eg3jmj5uncvcvk78ftcnf9ur7fgg09uv8k2mg5z8nd5evdmz6anmxjf3a0f2fasurwl8g2rrmfqh3wq0sdvtjrvmhqpftqpvq5sjanx0mnjnqxhc53nvcuwc2kftj32k5u6g2hjhfck2cldplfphspgy9ay6zgezxucsg4lqgzneqd67tjfshtce94hhr0sgdwkcvur2a94zw6jcd3qk3j93d28tfxff8faq676r2upd4z9g98rgewvrttrchashzz2yqk9c3txpr9sjvurmgzwk2vznpdg7ur8crkdwud6crvs2x5r62e5hxpfxmfqrklr9jzt49543z4j3v7jgst9tfwmvae8g4277rp73vfrgljscv2tzawzgev9gzy074xznl9nyp4vz3uk9e4re9nq0ss8rhzsmwc640l3sc7d4gvcue2lmq9rpaddcaqdndes6je7h9dh89nptpytf5764nfdxdpwrgfk5cergz0fgkwxx8mleygrmqmratu37rac9yugfqjjv5zg00j3kzvuaqw4n265204q2nfzpsgnnfw3263y2k6u8x4y3scqs8y3kggwvayehchlgdad5rvp5q3v9rqza3ja6u3mj8cpxz0eyvs6slgn0harz5pqr9jhjcnjy0pk70g34y2js9xc59zcx2pyf39t0ghq4fzum7yh6egt4czvkysz2snzjw8e6amkvfjd2qhllvg95v4nzca2qjtsq5hzrx4gzwexylpt9az9cc8mnfsajt8k7w3yerkaz2ppftmeynee4q76cpqptukte2unpacmk8qvkjva7nf0xuxclappnscrs3pmdcmzsqu6rvep2zlgzjcg3grems23xj3jmxcu00m7pqnh3chsvz7es62qr4r9ey65cyw6hdasvvy7efpwdpx9tetcg8mc3ynpf3t9tmzpyywma073rqs42c2sljw6f7dee70p7wvn4fexteq4whdhrweqk65nrdqmh0mzgq606gnv26y0nc54qzu0z0n0j6vyctc8mnpu686cflsat5maje8anuma0l0gaakg9u79ddu4ugm023pspf7c3udh2847rp3ajkcrvzj7a45tgkejszqcnt359
  - &host_ssh_age age19tt5uzx22g05wfwzmqaksl4f5lpphmu9hzfgp82y4zn2vv6w5uwqej8v23
  - &host_ssh ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJO6w8KI70f22aYECLsvds6fsYPQWrsyYpzlwZIArabv


creation_rules:
  - path_regex: host_pq.yaml
    key_groups:
      - age:
        - *admin_pq
        - *host_pq

  - path_regex: host_ssh_age.yaml
    key_groups:
      - age:
        - *admin_pq
        - *host_ssh_age

  - path_regex: host_ssh.yaml
    key_groups:
      - age:
        - *admin_pq
        - *host_ssh
```

[pq][pq system]
: Uses exclusively post-quantum Age keys for encryption and decryption.

[ssh_age][ssh_age system]
: Uses a post-quantum Age key for encryption, and an Age key derived from an
  Ed25519 SSH key for decryption.

[ssh][ssh system]
: Uses a post-quantum Age key for encryption, and an Ed25519 SSH key for
  decryption.

As an aside, you really should use a separate "admin" key for managing your
secrets. This admin key will be added as a recipient to all the targets, but
will not be deployed to any machine. Each machine then gets its own recipient,
scoped to the minimum targets it needs. In the example code above, if the `pq`
machine was compromised, it would still be unable to decrypt secrets from
`host_ssh_age.yaml` or `host_ssh.yaml`.
{ class = "aside" }

The keys used in each system are available in the
[credentials dir][credentials/], and
[automatically mounted into the virtual machines][credentials mount].

### Running each target in a VM

The previously linked [guide][NixOS virtual machines] contains more
information, as well as instructions on how to run a VM with a graphical
interface. Here we are only checking a few files so I went with a terminal VM:

```sh
$ nix build .#nixosConfigurations.pq.config.system.build.vm
$ ./result/bin/run-pq-vm
```

{{< figure
	src="./vm.webp"
	alt="PQ NixOS system running in a QEMU VM"
	caption="It will spawn a terminal in a QEMU VM"
>}}

Username is `sighery` and password is `test` for all systems. Decrypted
secrets are under `/run/secrets/`. Each target has a differently named secret,
so it is easy to tell at a glance whether the proper secret is being decrypted
with the proper key. `pq` will decrypt `val1`, `ssh_age` `val2`, and `ssh`
`val3`.

### Encrypting new secrets with the admin_pq key

The [sops-nix documentation][sops-nix usage] recommends writing your private
key to `~/.config/sops/age/keys.txt`. I generally dislike this approach, since
you might forget to remove it after you are done editing, and with an admin
key, you really should remove it after use. Remember, admin keys can decrypt
_all_ targets.

[Sops accepts a few environment variables][Sops Age documentation] that allow
for different ways of passing the Age key. `SOPS_AGE_KEY_FILE` can be used to
specify a different file path:

```sh
$ SOPS_AGE_KEY_FILE=credentials/admin_pq sops host_pq.yaml
```

Even more secure, you can use `SOPS_AGE_KEY_CMD` so Sops will run a command
to retrieve the private key. You could couple this with `pass` or another
password manager and make it so the private key never exists on disk:

```sh { caption="Imagine I was using some fancy password manager here" }
$ SOPS_AGE_KEY_CMD="cat credentials/admin_pq" sops host_pq.yaml
```

Sadly [the CMD implementation][Sops Age CMD implementation] will not allow
`stdin`, limiting its effectiveness.
{ class = "aside" }


## Is this even worth worrying about?

Estimates vary widely on when sufficiently capable quantum computers will be
developed. Some (optimistic) estimations suggest as early as 2030, while
others estimate 30+ years.

Whichever it is, the consensus is that quantum computers will continue to
develop and eventually be able to break classical encryption, or a subset of.

With that in mind, I will try to get some of this added to the sops-nix
documentation, so more people are aware of Age supporting post-quantum
cryptography, as well as the potential risks of public secrets when using
classical encryption.



[Keeping NixOS secrets, secret]: https://sighery.com/posts/nixos-secrets-private-flake/
[sops-nix]: https://github.com/mic92/sops-nix
[Age]: https://age-encryption.org/
[Age v1.3.0]: https://github.com/FiloSottile/age/releases/tag/v1.3.0
[Age post-quantum keys]: https://github.com/FiloSottile/age/blob/b74dce4cdbe35b5e5f66c06d9612b72f89028758/README.md#post-quantum-keys
[OpenSSH PQ]: https://www.openssh.org/pq.html
[ssh-to-age]: https://github.com/Mic92/ssh-to-age
[sops-nix usage]: https://github.com/Mic92/sops-nix/blob/fe7b4228405aeac2ce7192c2049a6e2bc8637082/README.md#usage-example
[Age SSH recipients]: https://github.com/FiloSottile/age/blob/b74dce4cdbe35b5e5f66c06d9612b72f89028758/README.md#ssh-keys
[Sops Age SSH recipients]: https://getsops.io/docs/usage/identities/age/
[sops-nix SSH recipients PR]: https://github.com/Mic92/sops-nix/pull/970
[NixOS virtual machines]: https://nix.dev/tutorials/nixos/nixos-configuration-on-vm.html
[sops-nix-pq-exploration]: https://github.com/Sighery/sops-nix-pq-exploration
[pq system]: https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/secrets-pq.nix
[ssh_age system]: https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/secrets-ssh_age.nix
[ssh system]: https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/secrets-ssh.nix
[credentials/]: https://github.com/Sighery/sops-nix-pq-exploration/tree/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/credentials
[credentials mount]: https://github.com/Sighery/sops-nix-pq-exploration/blob/c07ea4be9e3d361d7c690b10404cb5ab42e0f388/configuration.nix#L17-L24
[Sops Age documentation]: https://getsops.io/docs/usage/identities/age/
[Sops Age CMD implementation]: https://github.com/getsops/sops/blob/9aa10f12bcd82400b7eb73331dd7a87a93bb17f7/age/keysource.go#L297-L317
