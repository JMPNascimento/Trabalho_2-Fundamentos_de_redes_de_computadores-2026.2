# FreeBSD Router Lab — Trabalho 02

Kit inicial para desenvolver a atividade de NAT + DHCP + DNAT em FreeBSD convencional, usando PF e Kea DHCPv4. Nao usa pfSense, OPNsense ou outro appliance de gateway.

> **Importante:** este kit e um ponto de partida didatico. Foi escrito para FreeBSD e validado quanto a sintaxe dos scripts shell e ao JSON gerado, mas nao foi executado em uma maquina FreeBSD nesta etapa. A sintaxe PF e a inicializacao do Kea devem ser confirmadas na VM antes da implantacao fisica. Os testes oficiais do trabalho devem ocorrer em hardware fisico, conforme o enunciado.

## 1. Requisitos

- FreeBSD convencional (preferencialmente a mesma versao na VM e no equipamento fisico).
- Duas interfaces de rede distintas: uma WAN e uma LAN.
- Acesso como `root`.
- Acesso ao repositorio de pacotes do FreeBSD para instalar `kea`.
- Uma maquina de teste na WAN e pelo menos uma na LAN.

## 2. Arquivos

```text
freebsd-router-kit/
├── config/
│   └── router.conf
├── scripts/
│   ├── common.sh
│   ├── install.sh
│   ├── configure.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── validate.sh
│   ├── status.sh
│   └── show-leases.sh
├── tests/
│   ├── lan-run-dnat-server.sh
│   ├── wan-test-dnat.sh
│   ├── wan-run-test-server.sh
│   ├── lan-test-nat.sh
│   ├── lan-test-ping-block.sh
│   └── lan-renew-dhcp.sh
└── README.md
```

## 3. Topologia de exemplo para a VM

| Equipamento | Interface/rede | Endereco de exemplo |
|---|---|---|
| FreeBSD Router WAN | `vtnet0` / WAN-LAB | `192.168.50.10/24` |
| FreeBSD Router LAN | `vtnet1` / LAN-LAB | `10.0.0.1/16` |
| WAN Tester | WAN-LAB | `192.168.50.2/24` |
| LAN Client / servidor DNAT | LAN-LAB | DHCP; reserva `10.0.0.10` |

No UTM/QEMU, crie duas redes virtuais isoladas e conecte a interface WAN do roteador e o WAN Tester a WAN-LAB. Conecte a interface LAN do roteador e o LAN Client a LAN-LAB. Nao conecte a LAN-LAB em bridge com a rede real do laboratorio.

Os nomes `vtnet0` e `vtnet1` sao exemplos. Rode `ifconfig` e ajuste `config/router.conf`.

## 4. Configure os parametros

Edite `config/router.conf`. Os campos mais importantes:

- `WAN_IF` e `LAN_IF`: nomes reais das interfaces.
- `WAN_MODE`: `static` ou `dhcp`.
- `WAN_STATIC_ADDRESS`, `WAN_PREFIX`, `WAN_GATEWAY`: dados fornecidos pelo professor ou usados na WAN de teste.
- `LAN_ADDRESS`, `LAN_NETWORK`, `LAN_PREFIX`: mantenha a rede LAN /16 exigida.
- `DNS_SERVER`: use o DNS informado pelo professor. O valor de exemplo e `164.41.101.4`.
- `DHCP_RESERVED_MAC`: MAC real do cliente que deve receber sempre o mesmo IP. Na VM, configure o MAC do cliente como `02:00:00:00:00:10` ou altere este campo para o MAC existente.
- `WAN_TEST_SERVER_IP` e `ROUTER_WAN_TEST_IP`: enderecos dos testes TCP.

O arquivo vem com valores de exemplo para uma rede WAN virtual isolada. Antes da validacao fisica, substitua-os pelos dados reais do laboratorio. O `X` de `192.168.X.0/24` deve ser substituido pelo valor informado pelo professor.

## 5. Instalar, configurar e iniciar

Execute a partir da raiz do projeto, no FreeBSD:

```sh
chmod +x scripts/*.sh tests/*.sh
su -
cd /caminho/freebsd-router-kit
./scripts/install.sh
./scripts/configure.sh
```

O instalador usa `pkg` para instalar o pacote `kea`. O configurador:

1. verifica as interfaces;
2. gera `/etc/pf.conf`;
3. gera `/usr/local/etc/kea/kea-dhcp4.conf`;
4. valida ambos os arquivos antes de instala-los;
5. grava as configuracoes persistentes em `/etc/rc.conf.local`;
6. faz backup de configuracoes anteriores.

O script nao reinicia automaticamente as interfaces, para evitar derrubar uma sessao remota. Na primeira configuracao, reinicie o FreeBSD pela console local para aplicar `/etc/rc.conf.local`:

```sh
reboot
```

Depois do reboot:

```sh
./scripts/validate.sh
./scripts/start.sh
./scripts/status.sh
```

`start.sh` aplica a configuracao LAN, garante `net.inet.ip.forwarding=1`, carrega PF/pflog e inicia Kea DHCPv4.

## 6. Testes funcionais

### 6.1 DHCP e reserva

No cliente conectado somente a LAN:

```sh
./tests/lan-renew-dhcp.sh vtnet0
```

A interface do cliente deve receber um endereco do pool. Para a maquina cujo MAC esta em `DHCP_RESERVED_MAC`, o endereco deve ser sempre `DHCP_RESERVED_IP` (por exemplo, `10.0.0.10`).

No roteador:

```sh
./scripts/show-leases.sh
```

Arquivos usados:

- Banco persistente de leases: `/var/db/kea/dhcp4.leases`.
- Eventos do servidor DHCP: `/var/log/kea/kea-dhcp4.log`.

Tambem e possivel acompanhar o log ao vivo:

```sh
tail -f /var/log/kea/kea-dhcp4.log
```

### 6.2 NAT de saida

Na maquina WAN, inicie um servidor TCP:

```sh
./tests/wan-run-test-server.sh 9000
```

Na maquina LAN, conecte-se a ele:

```sh
./tests/lan-test-nat.sh 192.168.50.2 9000
```

Na maquina WAN, observe a conexao recebida. A origem deve ser o IP WAN do roteador, nao o IP privado da LAN. Para registrar pacotes:

```sh
tcpdump -n -i <interface-wan> tcp port 9000
```

### 6.3 DNAT TCP/80 para TCP/8080

Na maquina LAN reservada (`10.0.0.10`), inicie:

```sh
./tests/lan-run-dnat-server.sh 8080
```

Na maquina WAN, execute:

```sh
./tests/wan-test-dnat.sh 192.168.50.10
```

A mensagem enviada pela WAN deve aparecer no terminal do servidor LAN. O IP informado deve ser o endereco WAN atual do roteador.

### 6.4 Bloqueio de ping encaminhado

Na maquina LAN:

```sh
./tests/lan-test-ping-block.sh 192.168.50.2
```

O ping nao deve receber resposta. Como ausencia de resposta, sozinha, nao prova que o PF bloqueou o pacote, confirme tambem no roteador:

```sh
pfctl -vvsr
tcpdump -n -i pflog0 icmp
```

A regra de bloqueio usa `log quick`, portanto os pacotes correspondentes devem aparecer em `pflog0`.

### 6.5 Isolamento

- Da WAN, tente conectar diretamente a um servico LAN que nao foi publicado: deve falhar.
- Da WAN, a porta TCP/80 do roteador deve ser a excecao e chegar ao servidor LAN na porta TCP/8080.
- Da LAN, conexoes de saida devem funcionar e aparecer na WAN com o endereco WAN do roteador como origem.

Lembre que NAT, isoladamente, nao e um firewall. O isolamento de entrada decorre tambem da politica `block all` e das excecoes explicitas no PF.

## 7. Comandos uteis para evidencias

No roteador:

```sh
ifconfig
netstat -rn -f inet
sysctl net.inet.ip.forwarding
pfctl -s info
pfctl -sr
pfctl -sn
pfctl -ss
pfctl -vvsr
```

Captura DHCP:

```sh
tcpdump -ni <interface-lan> 'udp port 67 or udp port 68'
```

Captura de pacotes bloqueados pelo PF:

```sh
tcpdump -ni pflog0 icmp
```

## 8. Observacoes e limitacoes do prototipo

- A configuracao cobre IPv4, conforme o enunciado. IPv6 nao foi configurado como parte do roteamento.
- O bloqueio ICMP trata especificamente ICMP Echo Request (ping) originado na LAN e destinado fora da LAN; outros tipos ICMP nao sao bloqueados por essa regra.
- O pool DHCP e amplo porque a LAN e /16. A reserva `10.0.0.10` fica fora do pool dinamico.
- O DNS e apenas anunciado aos clientes pelo DHCP; este roteador nao executa servidor DNS.
- A regra PF libera o servico redirecionado TCP/8080 no servidor LAN. Restrinja a origem se o professor exigir uma politica mais fechada.
- O endereco WAN `192.168.50.10` e apenas exemplo. Em WAN por DHCP, atualize `ROUTER_WAN_TEST_IP` para o endereco efetivamente recebido antes de usar o script de teste DNAT.
- O script `stop.sh` interrompe o firewall; use somente em ambiente de laboratorio e pela console local.
- Antes da validacao real, confirme os nomes das interfaces, o modo de enderecamento WAN, o DNS e o MAC reservado. Nunca conecte o servidor DHCP da LAN diretamente a rede cabeada do laboratorio.

## 9. Fontes oficiais

- FreeBSD Handbook — Firewalls/PF: https://docs.freebsd.org/en/books/handbook/firewalls/
- Manual `pf.conf` do FreeBSD 15.1: https://man.freebsd.org/cgi/man.cgi?query=pf.conf
- Kea DHCPv4 Administrator Reference Manual: https://kea.readthedocs.io/
- Pacote Kea no FreeBSD Ports: https://www.freshports.org/net/kea/
