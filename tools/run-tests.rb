require "digest/sha1"
require "rexml/document"

TEST_DIR = File.join(__dir__, "nes-test-roms")
unless File.exist?(TEST_DIR)
  system("git", "clone", "https://github.com/christopherpow/nes-test-roms.git", TEST_DIR)
end

EXCLUDES = [
  # need work but tentatively...
  "other/midscanline.nes",
  "scrolltest/scroll.nes",
  "mmc3_irq_tests/6.MMC3_rev_B.nes",

  # mappers 0, 1, 2, and 3 are suppored
  "exram/mmc5exram.nes",
  "nes-test-roms/mmc3_test/6-MMC6.nes",

  # looks pass?
  "read_joy3/count_errors.nes",
  "read_joy3/count_errors_fast.nes",

  # unsure (no output)
  "dmc_tests/buffer_retained.nes",
  "dmc_tests/latency.nes",
  "dmc_tests/status.nes",
  "dmc_tests/status_irq.nes",

  # full palette is not supported yet
  "full_palette/flowing_palette.nes",
  "full_palette/full_palette.nes",
  "full_palette/full_palette_smooth.nes",
  "other/blargg_litewall-2.nes",
  "scanline/scanline.nes",
  "other/litewall5.nes",
  "other/RasterDemo.NES",
  "other/RasterTest1.NES",
  "other/RasterTest2.NES",
  "dpcmletterbox/dpcmletterbox.nes",

  # tests that Nestopia fails
  "apu_reset/4017_written.nes",
  "blargg_ppu_tests_2005.09.15b/power_up_palette.nes",
  "cpu_interrupts_v2/cpu_interrupts.nes",
  "cpu_interrupts_v2/rom_singles/4-irq_and_dma.nes",
  "cpu_interrupts_v2/rom_singles/5-branch_delays_irq.nes",
  "ppu_open_bus/ppu_open_bus.nes",
  "sprdma_and_dmc_dma/sprdma_and_dmc_dma.nes",
  "sprdma_and_dmc_dma/sprdma_and_dmc_dma_512.nes",
  "stress/NEStress.NES",

  # tests that Neciside fails (wrong tvsha1?)
  "dmc_dma_during_read4/dma_2007_read.nes",
  "dmc_dma_during_read4/dma_4016_read.nes",
  "oam_stress/oam_stress.nes",
  "other/read2004.nes",
]

# rubocop:disable Metrics/LineLength
SOUND_SHA1 = {
  ["apu_mixer/dmc.nes", "dbPq1gWhVJbjPvi61pn/0dUVy/s="] => "7A5a8FmCvRTKu/zqQNodaIqUJR0=",
  ["apu_mixer/noise.nes", "eZG7kHcDAzvFUFMXjZynRd3ZyRU="] => "4YaRtnR8eT+V4l4t9/Q4ARPr7sI=",
  ["apu_mixer/square.nes", "JXc9txqBccnWpiYoJcNv/D05uCA="] => "yvxKtIzHrSo2BVK29yUHQLP3b64=",
  ["apu_mixer/triangle.nes", "CF8XZLs+e9CFTikZ1gHoVjTtWns="] => "sl61rBXsBvu0VhWypk93u6ERerA=",
  ["apu_reset/4015_cleared.nes", "75NVOeAT7/jVw73+CEdeKsb2Pic="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["apu_reset/4017_timing.nes", "DDBAM0I78ZhN6S88HzO1gN3WHA8="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["apu_reset/irq_flag_cleared.nes", "75NVOeAT7/jVw73+CEdeKsb2Pic="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["apu_reset/len_ctrs_enabled.nes", "75NVOeAT7/jVw73+CEdeKsb2Pic="] => "AKyS2S0k5hMo8Bj/O44pnJlNGuQ=",
  ["apu_reset/works_immediately.nes", "75NVOeAT7/jVw73+CEdeKsb2Pic="] => "YSwNsc5Zzgkbrhpqk/lZMgdcbdM=",
  ["apu_test/apu_test.nes", "WbE12eKlTfjwenhtU0Tq70qsaqQ="] => "hEARpWcoV8QegKdqxapnIjcn9TY=",
  ["apu_test/rom_singles/1-len_ctr.nes", "1EjN5lks7VxI/HHTIMDfb1GX/lo="] => "StJukmkZ1LFKc38CfxmwPClL79o=",
  ["apu_test/rom_singles/2-len_table.nes", "5dFdw9vsWOZg08m95wH7IY5Sry8="] => "4d3rtEiqiGbtkziq+EyGKVFpVdo=",
  ["apu_test/rom_singles/3-irq_flag.nes", "bpfq4a8sy8g2F6/RvruaQkcngtM="] => "7RqNzoebK/CYIu5d8MkNWy0n0Jc=",
  ["apu_test/rom_singles/4-jitter.nes", "b568KWtuumfzfyQCnq43g0twLAg="] => "ZPP/CEbpJPk3RdJS8j8b9NKJ1fg=",
  ["apu_test/rom_singles/5-len_timing.nes", "w+7iZgC2jbZcjILdYvftOC35b+U="] => "b9IkSy142e10izFFHMmrEbIsfm0=",
  ["apu_test/rom_singles/6-irq_flag_timing.nes", "Mt3McQrpQOTzXZB4gS0IV0kMqDA="] => "5v9zA2nlCb1zKR/FoRvV3hksSUI=",
  ["apu_test/rom_singles/7-dmc_basics.nes", "pBC+8N0h/pcYXTm7k6Bs3rnYf0E="] => "OMuLVW9QGV2ZG574pkLsW67TmEM=",
  ["apu_test/rom_singles/8-dmc_rates.nes", "mW8OnTTRl7lokJSVQ8//h5sANzk="] => "u3ttHSALo6lcmleFLkAlx/+0SfM=",
  ["blargg_apu_2005.07.30/01.len_ctr.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "T+XhxYyM5iG7AAZ2WtW6WnCw6Qg=",
  ["blargg_apu_2005.07.30/02.len_table.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "izagmEimywCQckeZoQNIfaV10CQ=",
  ["blargg_apu_2005.07.30/03.irq_flag.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "ixvTINbLedgGHQolX/LL91U9CnU=",
  ["blargg_apu_2005.07.30/04.clock_jitter.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "jdckH4QcPeIBCRSI5hbtQB4nsl8=",
  ["blargg_apu_2005.07.30/05.len_timing_mode0.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "qFFfjZSXx/gETae3nIUeqPqrU9o=",
  ["blargg_apu_2005.07.30/06.len_timing_mode1.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "nljQzO+sZL471oRdddXCfwuP8Tg=",
  ["blargg_apu_2005.07.30/07.irq_flag_timing.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "JX+rGHLHGbM8UHrF0QCis1STfAg=",
  ["blargg_apu_2005.07.30/08.irq_timing.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "i0x1uWufTgNNC483Bbbfkl5XMC8=",
  ["blargg_apu_2005.07.30/09.reset_timing.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "vL8ts7xjPgr9b2NC8XImdKluaXw=",
  ["blargg_apu_2005.07.30/10.len_halt_timing.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "iJNHM5c027/9aS3rDRpV3prc6DI=",
  ["blargg_apu_2005.07.30/11.len_reload_timing.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "Mc9zSq/CB54EMtJmBFDP7v9+8eM=",
  ["blargg_nes_cpu_test5/cpu.nes", "2/JXgutt9eKd6bBL4vjk1iJ7lpM="] => "yfHW1TAg8tCHCoBCkzHZqfrmIvk=",
  ["blargg_nes_cpu_test5/official.nes", "2/JXgutt9eKd6bBL4vjk1iJ7lpM="] => "oOCXQOdX+ekbaMUjDeLKPDwmWuY=",
  ["blargg_ppu_tests_2005.09.15b/palette_ram.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "DTzrtpk/qotzzyeaPduvd/9bAg4=",
  ["blargg_ppu_tests_2005.09.15b/sprite_ram.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "DTzrtpk/qotzzyeaPduvd/9bAg4=",
  ["blargg_ppu_tests_2005.09.15b/vbl_clear_time.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "K31u/aYrfTBatl+/owMIKx1qnb8=",
  ["blargg_ppu_tests_2005.09.15b/vram_access.nes", "2ACKiuKHeQth9xxXEZtgRQUIi6w="] => "DTzrtpk/qotzzyeaPduvd/9bAg4=",
  ["branch_timing_tests/1.Branch_Basics.nes", "NTpzRpbjMHVYziSDAZpwThpaDDg="] => "qhSohh6jNIOM3G7cIZr8+hbfcf4=",
  ["branch_timing_tests/2.Backward_Branch.nes", "BGjGkBOMnGfR2X4B2d3H/VSsPxw="] => "q0+WmzMpTdMDE62EJkGbCGDgSU8=",
  ["branch_timing_tests/3.Forward_Branch.nes", "S2UdyUN17QLEAbTPnM/sTGinkxo="] => "q0+WmzMpTdMDE62EJkGbCGDgSU8=",
  ["cpu_dummy_reads/cpu_dummy_reads.nes", "IZ7If73DZSDpOamXOmHx+MzmPBI="] => "7Vd90hahlt+FgOGTS7Za2T0ZnWk=",
  ["cpu_interrupts_v2/rom_singles/1-cli_latency.nes", "SpC0wIweffQZSre327sLMWsRfP4="] => "FIh2IIunZkL2rtPFLN4/UgHa3ck=",
  ["cpu_interrupts_v2/rom_singles/2-nmi_and_brk.nes", "G51vjIhxdNPMxGRkDStGjECiZdo="] => "pbDTvwK60s4R9Pi3je2L8o9iepg=",
  ["cpu_interrupts_v2/rom_singles/3-nmi_and_irq.nes", "nhdRKkcnEqojeRlTCr+F1kMz9IU="] => "8jAMSwsYvEKmkAJ6uNS8suMW89U=",
  ["cpu_reset/ram_after_reset.nes", "FiAsKo3Df69PZWd5r9lcCTxzKvM="] => "Fsj/D9Vt5HSiigf2ryGzPRcNOqc=",
  ["cpu_reset/registers.nes", "FiAsKo3Df69PZWd5r9lcCTxzKvM="] => "Fsj/D9Vt5HSiigf2ryGzPRcNOqc=",
  ["cpu_timing_test6/cpu_timing_test.nes", "fpbbQbbXCLSJiqSqKtGpjfhQ/Gc="] => "NmPFtldwhbtKpoJONIgYslwkTFc=",
  ["cpu_timing_test6/cpu_timing_test.nes", "pxjbcfJBNDWLLRn+1n1PARRTKAo="] => "/2vgArRQcGp7W4VxnHGkheup49s=",
  ["cpu_timing_test6/cpu_timing_test.nes", "qiCw5Tc02sYX/zr58+sSEm2thAY="] => "FGYhdM0eDiF1jEwMNKaOdJPI2fY=",
  ["dmc_dma_during_read4/dma_2007_write.nes", "UvqdCGEKiDqwDsHUpSsqN1BvI9Y="] => "nCyvymYwIGyo1b2JlsGTlBmBrEk=",
  ["dmc_dma_during_read4/double_2007_read.nes", "n8KPQ9tB6W6iemDYSyinaCXRIZI="] => "SCT3Ie8zfgGzgsX54g18a+dz20w=",
  ["dmc_dma_during_read4/read_write_2007.nes", "ogLiZLQg2KSbdltpnma896mtmiI="] => "hcbQiENATEK9SgtnqA0UAN4wlzI=",
  ["instr_misc/instr_misc.nes", "iZ2XYkUeZjv5ePYE9Md5lU8+H28="] => "YqiUhvws22w9aBXWvrUxHSxW6UU=",
  ["instr_misc/rom_singles/01-abs_x_wrap.nes", "WCx7tS1Mwo8NqngfulG9adk1kiM="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["instr_misc/rom_singles/02-branch_wrap.nes", "jlVAxP0SaI05NPtuUeT7Ob9iero="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["instr_misc/rom_singles/03-dummy_reads.nes", "tyTlCPdKk4iSaZJ3xdOFhBnVHuk="] => "pyl2P2yitKVZoe3fYbktKPt47cQ=",
  ["instr_misc/rom_singles/04-dummy_reads_apu.nes", "oORp9qLG3OmJzJHQIEjAp7XTlWE="] => "Fsj/D9Vt5HSiigf2ryGzPRcNOqc=",
  ["instr_test-v3/all_instrs.nes", "RBzdRMiDUkizcDzxfBgd+ahh1NM="] => "NZctmuvl68P0a/cOM43C9qOqfQE=",
  ["instr_test-v3/official_only.nes", "RBzdRMiDUkizcDzxfBgd+ahh1NM="] => "UH3ii97LbYXghoVHAv6AAmCmdWc=",
  ["instr_test-v3/rom_singles/01-implied.nes", "n7U5RnFgcdb7kFV1dZfksAqUBMs="] => "rfg0NB23WKlPhxvIP/E9BH2h7QY=",
  ["instr_test-v3/rom_singles/02-immediate.nes", "OYTH2t40zTRfpTnF1GKsxZ8vna8="] => "Mw3e2G3dkxOf9ttR/mmP8c9vMsc=",
  ["instr_test-v3/rom_singles/03-zero_page.nes", "IWJ0/os7GyhIQ8/7297rlGQmJpU="] => "JBuzZ1Yw2VddN4jXY8NbvBhlFfI=",
  ["instr_test-v3/rom_singles/04-zp_xy.nes", "sUn1ZLzjfc0byz6/iacouftCNaU="] => "YUxhdvXzyPzfgSfFjEQgyan4VwM=",
  ["instr_test-v3/rom_singles/05-absolute.nes", "y/bns/H8tdQCdiqYWMn0qzAr+00="] => "MJiVpNF2L0o9wdk6J2yO1hgyYzQ=",
  ["instr_test-v3/rom_singles/06-abs_xy.nes", "jS2Zgrjd3BU3Jj8qobdUWF0nxPk="] => "1V5zrgtgDMKm89xFRT7dyq9epjU=",
  ["instr_test-v3/rom_singles/07-ind_x.nes", "LdpOb9FUY/7uVET7saATEPXPTD0="] => "UJhkGe6BLE1P0NHtxNUNs7g3YS8=",
  ["instr_test-v3/rom_singles/08-ind_y.nes", "M87UDz5ijJzD1v5ioFB7dJqUXSo="] => "3nC87AdNAX3k5VXlPYHGWaGGwKw=",
  ["instr_test-v3/rom_singles/09-branches.nes", "WJVcKaRUZPErFU0/UISvG+x8Czw="] => "CykT9oq8cTN5imKiFWtgUrvHOKI=",
  ["instr_test-v3/rom_singles/10-stack.nes", "mDhsrKJkaoGI162u/ZDMjgeEZn4="] => "XFlUxQtLu0yxl/Pg7Y1mSnED3jg=",
  ["instr_test-v3/rom_singles/11-jmp_jsr.nes", "pn0CDLxK0Btl8ogs7cZs5s9mFig="] => "P4hl+vU2KfULEt3qKMnfc2V6Fn8=",
  ["instr_test-v3/rom_singles/12-rts.nes", "Q+FItBqJ35fSJUxezY7rDohGpj8="] => "sGhlDOeuO0eIe4fDJvTWY/llxhQ=",
  ["instr_test-v3/rom_singles/13-rti.nes", "mC53jqJUSVgt6Mab5p9vTFGF4pA="] => "6h6dFyda19rd7QrK5Cd2azeMDSA=",
  ["instr_test-v3/rom_singles/14-brk.nes", "SRIwi0+9JMhuZnb1SgkMfolFpSQ="] => "2xJL8U8lbirqcKffGd9WKKsxhsE=",
  ["instr_test-v3/rom_singles/15-special.nes", "oNLQxerG1cRgxFHLi3pWOmeHVDY="] => "WtysSS9Gt2b0KdF/G6BGWlN2DJ8=",
  ["instr_timing/instr_timing.nes", "J7ka+aDZntB3l83JlCXW9nTY/uY="] => "296EYJ+Q7AgBBh+oRqKfIRRFHTY=",
  ["instr_timing/rom_singles/1-instr_timing.nes", "ZCRfNt3EX1IneK9Ai/OiCbUwNzE="] => "A/Novd1ECXRjtevLiEGmhvQh0fc=",
  ["instr_timing/rom_singles/2-branch_timing.nes", "086PXJoyijU44W2y4tTDtkIGR2M="] => "ZZ3NSyG+IBmWledXwGPIXGPxlYs=",
  ["mmc3_irq_tests/1.Clocking.nes", "ZqkTHgTTAPpDRn9sqNad2yz5pYs="] => "nKoU9CIS+Mg1TNQVXvOiyGunpbs=",
  ["mmc3_irq_tests/2.Details.nes", "R026+0tGfi7uc9HyUeDCFq0sxJw="] => "JqrN9phWyedireHOKmjgr7ojJSs=",
  ["mmc3_irq_tests/3.A12_clocking.nes", "kQuwXXwPR/0Lwzwy6McyfEFiXDs="] => "nKoU9CIS+Mg1TNQVXvOiyGunpbs=",
  ["mmc3_irq_tests/4.Scanline_timing.nes", "HEO9IvZ5q+kZgHEfpldi1kMwrzA="] => "CeFd73VY8If4/VYeeX6GpT8nwgs=",
  ["mmc3_irq_tests/5.MMC3_rev_A.nes", "kZ+G1y5kY+7Yirs8wbD/JHQzUHs="] => "aunJndZGIh0HO7msCVirdFPkrDY=",
  ["mmc3_test/1-clocking.nes", "/6lQUCFnZUjfw6pW46LqKU4n6Sk="] => "2Lt0m+OFqn7dtKKA8y0cs8BkxNs=",
  ["mmc3_test/2-details.nes", "e6ZUPFCkoRfTNNKJsMOIv0C8pjw="] => "RsyAZ9W81udDs0jsTBOj9MKzUtQ=",
  ["mmc3_test/3-A12_clocking.nes", "3Srp4z0tNrT8KeU0XszHGGGXwP0="] => "2Lt0m+OFqn7dtKKA8y0cs8BkxNs=",
  ["mmc3_test/4-scanline_timing.nes", "wvBhqyDa7lGGy5Nyx6kMAAV2wQA="] => "4/TzDoKRKjmAnLdc4JFLlEwnJR4=",
  ["mmc3_test/5-MMC3.nes", "e2HtOAagMzn8vT2R47TuHtEoEGw="] => "PvELODjaLCoODEFOYHVXSgrsd9U=",
  ["mmc3_test/6-MMC6.nes", "1D7g0UPazJz8zECHs09dVaFrrEo="] => "pBJxYjxhgZhyzJ13ZCCk341yAQg=",
  ["nmi_sync/demo_ntsc.nes", "VPaA+wEVi+G1LeopdAmHRiATX1M="] => "pyl2P2yitKVZoe3fYbktKPt47cQ=",
  ["oam_read/oam_read.nes", "5yTFeVWQR69gVIx9N/0dNjK6bO4="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/PCM.demo.wgraphics.nes", "pHRC5undB25lm7rgcB7K44YpZkE="] => "207rRnocGSQWzc/zAtjc06mVAgo=",
  ["other/RasterChromaLuma.NES", "qvAWjQxmhejvqAhlydizmjekinc="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3.NES", "ZQDyp7EioQrVBlgUAjoxtY8NbLk="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3a.NES", "ExxlU4SEW1lZZTqvHJsxS95TToU="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3b.NES", "GQLGeg3+Qk4fv7JYweCNHvaA4Tk="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3c.NES", "KjlFw7WJNtCr13OasylAmuCY2aw="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3d.NES", "N2QzIE0OX4Bbhpx/NLPTpinu6Po="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/RasterTest3e.NES", "jJDtkpyMOz2NTtgbhhFi7KXZWpw="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/S0.NES", "x7tDPDXKlymWFCPRowQlOdQjJu4="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["other/nestest.nes", "9TB6z7tvI3VzIlngozSjdBQ6Ils="] => "iW/M8yCUxpt9+V0Lps4VOErUHZw=",
  ["ppu_vbl_nmi/ppu_vbl_nmi.nes", "6X5+GM6YQfB4enaqJlBrDa5Qtzo="] => "SgGSPn0ydicTU/ZneKToa+33OoU=",
  ["ppu_vbl_nmi/rom_singles/01-vbl_basics.nes", "CpMy2y52QJB1+Ut8CKgz9A7I344="] => "yOc3AWDQhdM5C0BId+8rg9LXRw4=",
  ["ppu_vbl_nmi/rom_singles/02-vbl_set_time.nes", "x5lMpbxxlMZKNkAZ3hr++SEy0Yw="] => "fpEcKZ2alK6yFVrnzlehFdeFBAs=",
  ["ppu_vbl_nmi/rom_singles/03-vbl_clear_time.nes", "QAVr0aXlcZpXVBtniaxXdRbazno="] => "OUNb+EDKT302cDD6ULrVfHi2Isk=",
  ["ppu_vbl_nmi/rom_singles/04-nmi_control.nes", "KLWQ7fq5zVi5d0PfwYWBLYCi7HY="] => "31hAYx286VKyU8ify6Vza4/Dj8c=",
  ["ppu_vbl_nmi/rom_singles/05-nmi_timing.nes", "p477oq82Zqm8ofQsXheCf+TCRTw="] => "cluFwHYcsnP20wDvVmkHJ+jLizM=",
  ["ppu_vbl_nmi/rom_singles/06-suppression.nes", "39xUI45+3b2+HH7LMGCcUNt4vKY="] => "SJl5Fe1NgjgqhuDN004PlPjm+RU=",
  ["ppu_vbl_nmi/rom_singles/07-nmi_on_timing.nes", "1g/TnrYgE7kiS0aaw2EdeQxl8D4="] => "d0ybf3ujcRqHWdm3e2eLHS8WmNc=",
  ["ppu_vbl_nmi/rom_singles/08-nmi_off_timing.nes", "29z8PGl7oPWYOP1/5cmj0/esdOo="] => "kKjjI+UICoSIA0ebd1aqbT5Ct3o=",
  ["ppu_vbl_nmi/rom_singles/09-even_odd_frames.nes", "l9ASihPBcYc0jKAp4LMM1gfEYP0="] => "z9hmupPjf/YpjnKIlNVb9rsbYrM=",
  ["ppu_vbl_nmi/rom_singles/10-even_odd_timing.nes", "UpPRP5OVU51XTAMS7RUE8iak/BI="] => "S8UzpC78XzZYcLAL/hJbFvurfYc=",
  ["read_joy3/test_buttons.nes", "zr4miqOZKgHF0LMqQqYckcxINbY="] => "YwXAIBxfvdFvnN2qiHwPtofNXH0=",
  ["read_joy3/thorough_test.nes", "z7/v0RtA9ptZx2NzMmfVMhKIL14="] => "FszUM0cBFYkl9GLYJ498yEzk8HI=",
  ["sprite_hit_tests_2005.10.05/01.basics.nes", "g/VxI/pEE1YgYC6i1WYWhEu39N4="] => "PplyMf9BlIO8npD1pR278A/wLVA=",
  ["sprite_hit_tests_2005.10.05/02.alignment.nes", "Sg/MGfJNAOW5g2iCM2QGzRONbhM="] => "boBCdv8q+mU1ehMctIDdb8B+a00=",
  ["sprite_hit_tests_2005.10.05/03.corners.nes", "V3ICSP+38/Z6SqOeQiYhKLQOW5w="] => "5EMUi7MJ9mMgdeVAEk/4dy50+xI=",
  ["sprite_hit_tests_2005.10.05/04.flip.nes", "ejt5YTdLSEzx4oETy306J0tZoko="] => "nKoU9CIS+Mg1TNQVXvOiyGunpbs=",
  ["sprite_hit_tests_2005.10.05/05.left_clip.nes", "Cwde8FZMs6z3n1NDQHLsCVgsPQs="] => "Yuv+BICPLOLHepBiuEFWPjw7kR4=",
  ["sprite_hit_tests_2005.10.05/06.right_edge.nes", "Usj4WtxKj+6yjiAtjvt79cBBtOE="] => "JqrN9phWyedireHOKmjgr7ojJSs=",
  ["sprite_hit_tests_2005.10.05/07.screen_bottom.nes", "Wqt8ZHLfPp4BYy5MCsC2JCngqqw="] => "p3IjEio2yNsldPzm5KLEjyYeYrA=",
  ["sprite_hit_tests_2005.10.05/08.double_height.nes", "DfMiV6YRYgPxD+1B3T3FTuv+YJM="] => "5EMUi7MJ9mMgdeVAEk/4dy50+xI=",
  ["sprite_hit_tests_2005.10.05/09.timing_basics.nes", "+dRfx/nvSLg4Gls5cGwKB4WQD5E="] => "qfbgrs9dX+24ukO+KJuz+l61SBM=",
  ["sprite_hit_tests_2005.10.05/10.timing_order.nes", "rqcJD3McCNwA8LUu6SH2pAoMvUs="] => "Pdk2CCE92RGAYG1BGk7wYF0eEHI=",
  ["sprite_hit_tests_2005.10.05/11.edge_timing.nes", "I/QgailO8jvJADJbgXd2Wiztnhg="] => "EK6ip3zJLgMDY5OogCdKu+38gnE=",
  ["sprite_overflow_tests/1.Basics.nes", "j9zIKsi6wv884n3xjT1Y3aopymU="] => "yHFbGhrR/TQu4Qx5tIoPYs3tmj4=",
  ["sprite_overflow_tests/2.Details.nes", "Z1TvJ6ADX3xKIhAfPTK28VEnGAE="] => "aYD4/RFWcpkfZfyYZAQytxvCisI=",
  ["sprite_overflow_tests/3.Timing.nes", "YGCIdXFdv1QPGu4dX4SVOVDv18M="] => "gw++hMBS9AA/0zYpMt8kx/S0iHg=",
  ["sprite_overflow_tests/4.Obscure.nes", "G7QTo/aa6XTtLYiJuYep+JBoIyQ="] => "GkO5GKFfUQUalIsX4cHIVYl8Ao0=",
  ["sprite_overflow_tests/5.Emulator.nes", "FIMmXK96ioafYAgjHFtUDpJBUk0="] => "6BRNT7ff6Cd+fthGiS2Ke+4DlM8=",
  ["stomper/smwstomp.nes", "kCn0N3p5wTqvDiM8jKaLNzE9qpc="] => "CykvKb9WfOp6Kwd32RKxBiV1Bdk=",
  ["vbl_nmi_timing/1.frame_basics.nes", "92MKeu+BNV2FPH3kv1/K9bMxjrk="] => "1yAaANmuSLHLmpkAUIfSpEVQS/8=",
  ["vbl_nmi_timing/2.vbl_timing.nes", "W7dVlXd44bcC1IiV4leiH74T7mk="] => "4YfurCjuak9J8qEOu+uOq03wjXc=",
  ["vbl_nmi_timing/3.even_odd_frames.nes", "k+smsz5p87yWCYdp1OKa1YaXRQk="] => "ueJGL2HWMo+E6COlpAOFeN/JXVc=",
  ["vbl_nmi_timing/4.vbl_clear_timing.nes", "/ZLeXZYpV/qwGX7FfKRAjxn0otE="] => "xSs/gOC/DHG9w3umfuyyDLYdSMM=",
  ["vbl_nmi_timing/5.nmi_suppression.nes", "dj7JK/m85c5RceEBNDgxgRuRqw8="] => "5KRO6QzHUuepoi6gqK8IN0nts08=",
  ["vbl_nmi_timing/6.nmi_disable.nes", "tIJKYXx4bCWegJzob7wDNqXfYk0="] => "tF7TZ4GW++l6UxKySjL7Qh8XnbE=",
  ["vbl_nmi_timing/7.nmi_timing.nes", "7qr77ue+0LN1Rr3g51kSfjNTCj8="] => "tF7TZ4GW++l6UxKySjL7Qh8XnbE=",
}
# rubocop:enable Metrics/LineLength

# parse nes-test-roms/test_roms.xml
Test = Struct.new(:runframes, :filename, :filepath, :tvsha1, :input_log)
TESTS = []
open(File.join(TEST_DIR, "test_roms.xml")) {|io| REXML::Document.new(io) }.root.elements.each do |elem|
  # pal is not supported
  next if elem.attributes["system"] == "pal"
  filename = elem.attributes["filename"].tr("\\", "/")
  runframes = elem.attributes["runframes"].to_i

  runframes = 4000 if filename == "instr_timing/instr_timing.nes"
  filename = "stress/NEStress.NES" if filename == "stress/NEStress.nes"

  filepath = File.join(TEST_DIR, filename)
  tvsha1 = elem.elements["tvsha1"].text
  input_log = []
  elem.elements["recordedinput"].text.unpack("m").first.scan(/.{5}/m) do |s|
    cycle, data = s.unpack("VC")
    frame = (cycle.to_f / 29780.5).round
    input_log[frame] ||= 0
    input_log[frame] |= data
  end
  TESTS << Test[runframes, filename, filepath, tvsha1, input_log]
end

# ad-hoc patch
TESTS.each do |test|
  case test.filename
  when "cpu_interrupts_v2/rom_singles/1-cli_latency.nes"
    test.tvsha1 = "SpC0wIweffQZSre327sLMWsRfP4="
  when "mmc3_test/4-scanline_timing.nes"
    test.runframes = 360
    test.tvsha1 = "wvBhqyDa7lGGy5Nyx6kMAAV2wQA="
  when "mmc3_test/5-MMC3.nes"
    test.tvsha1 = "e2HtOAagMzn8vT2R47TuHtEoEGw="
  when "mmc3_irq_tests/6.MMC3_rev_B.nes"
    test.tvsha1 = "1D7g0UPazJz8zECHs09dVaFrrEo="
  end
end

if ARGV.empty?
  require "open3"
  TESTS.reject! {|test| EXCLUDES.include?(test.filename) }
  threads = []
  queue = Queue.new
  4.times do
    threads << Thread.new do
      while true
        test = TESTS.shift
        break unless test
        queue << Open3.capture3("ruby", __FILE__, test.filepath)
      end
      queue << nil
    end
  end
  num_pass = num_fail = 0
  while threads.any? {|th| th.alive? }
    out, _, status = queue.shift
    next unless out
    puts out
    if status.success?
      num_pass += 1
    else
      num_fail += 1
    end
  end
  puts "pass: #{ num_pass }, fail: #{ num_fail }"
else
  if ARGV[0] != "cov"
    argv = ARGV.map {|file| File.expand_path(file) }
    TESTS.select! do |test|
      argv.include?(test.filepath)
    end
  else
    require "simplecov"
    SimpleCov.start
    TESTS.reject! {|test| EXCLUDES.include?(test.filename) }
  end

  require_relative "../lib/optcarrot"
  TESTS.each do |test|
    begin
      nes = Optcarrot::NES.new(
        romfile: test.filepath,
        video: :png,
        audio: :wav,
        input: :log,
        frames: test.runframes,
        key_log: test.input_log,
        sprite_limit: true,
        opt_ppu: [:all],
        opt_cpu: [:all],
      )
      nes.reset
      sha1s = []
      test.runframes.times do
        nes.step
        v = nes.instance_variable_get(:@ppu).output_pixels[0, 256 * 240].flat_map do |r, g, b|
          [r, g, b, 255]
        end
        sha1 = Digest::SHA1.base64digest(v.pack("C*"))
        sha1s << sha1
      end
      raise "video: #{ test.tvsha1 } #{ sha1s.last }" unless sha1s.include?(test.tvsha1)

      sha1 = Digest::SHA1.base64digest(nes.instance_variable_get(:@audio).instance_variable_get(:@buff).pack("v*"))

      unless SOUND_SHA1[[test.filename, test.tvsha1]] == sha1
        raise "sound: #{ SOUND_SHA1[[test.filename, test.tvsha1]] } #{ sha1 }"
      end

      puts "ok: " + test.filename
      $stdout.flush
    rescue Interrupt
      raise
    rescue
      puts "NG: " + test.filename
      # rubocop:disable Style/SpecialGlobalVars
      p $!
      p(*$!.backtrace)
      # rubocop:enable Style/SpecialGlobalVars
      exit 1
    end
  end
end
