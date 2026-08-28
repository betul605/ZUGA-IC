#!/bin/bash
# ============================================================================
# run_regression.sh - ZUGA-IC AXI4-Lite Regression Suite
#
# 8 bagimsiz AXI4-Lite testbench'ini sirayla calistirir, sonuclari ozetler.
#
# Sartname §3.2.2 (test durum dokumu) ve §5.2 #3 (AXI Protocol Check) icin
# tek komutla regression dogrulamasi saglar.
# ============================================================================

set -e
cd "$(dirname "$0")"

echo "================================================================"
echo "ZUGA-IC AXI4-Lite Regression Suite"
echo "Tarih: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"
echo ""

PASS=0
FAIL=0
TOTAL_TX=0
TOTAL_HANDSHAKE=0
RESULTS=""

# Helper: tek test calistir
run_test() {
    local name="$1"
    local milestone="$2"
    local script="$3"
    local expected_tx="$4"

    echo "--- $milestone: $name ---"

    # Build + run, ciktiyi yakala
    if ./$script > /tmp/regression_${name}.log 2>&1; then
        # Test gec0ti mi kontrol
        if grep -q "ALL TESTS PASSED" /tmp/regression_${name}.log; then
            # Handshake sayilarini topla (varsa)
            local hs=$(grep -E "AW handshake|W  handshake|B  response|AR handshake|R  response" \
                      /tmp/regression_${name}.log | awk '{sum+=$NF} END {print sum+0}')

            echo "  PASS - $expected_tx transaction, $hs handshake"
            PASS=$((PASS+1))
            TOTAL_TX=$((TOTAL_TX+expected_tx))
            TOTAL_HANDSHAKE=$((TOTAL_HANDSHAKE+hs))
            RESULTS="${RESULTS}\n  $milestone $name: PASS ($expected_tx tx, $hs handshake)"
        else
            echo "  FAIL - 'ALL TESTS PASSED' bulunamadi"
            FAIL=$((FAIL+1))
            RESULTS="${RESULTS}\n  $milestone $name: FAIL"
        fi
    else
        echo "  FAIL - build/run hatasi"
        FAIL=$((FAIL+1))
        RESULTS="${RESULTS}\n  $milestone $name: FAIL (build error)"
    fi
    echo ""
}

# ============================================================================
# Testler
# ============================================================================

run_test "axi_bridge"      "M17" "build_axi.sh"             12
run_test "ram_axi"         "M18" "build_ram_axi.sh"          4
run_test "boot_rom_axi"    "M29" "build_boot_rom_axi.sh"     6
run_test "gpio_axi"        "M19" "build_gpio_axi.sh"         5
run_test "timer_axi"       "M20" "build_timer_axi.sh"        5
run_test "uart_axi"        "M21" "build_uart_axi.sh"         6
run_test "uart_dual_axi"   "M31" "build_uart_dual_axi.sh"    6
run_test "uart_rx_axi"     "M53" "build_uart_rx_axi.sh"      5
run_test "yz_csr_axi"      "M65" "build_yz_csr_axi.sh"       8
run_test "i2c_master_axi"  "M22" "build_i2c_axi.sh"          5
run_test "qspi_master_axi"  "M69" "build_qspi_axi.sh"        5

# ============================================================================
# Ozet Rapor
# ============================================================================

echo "================================================================"
echo "REGRESSION OZET RAPOR"
echo "================================================================"
echo -e "$RESULTS"
echo ""
echo "----------------------------------------------------------------"
echo "PASS:        $PASS / $((PASS+FAIL))"
echo "FAIL:        $FAIL"
echo "Toplam Tx:   $TOTAL_TX transaction"
echo "Handshake:   $TOTAL_HANDSHAKE"
echo "----------------------------------------------------------------"

if [ $FAIL -eq 0 ]; then
    echo "SONUC: TUM TESTLER GECTI ✓"
    exit 0
else
    echo "SONUC: $FAIL TEST BASARISIZ ✗"
    exit 1
fi
