library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        clk     : in  std_logic;  -- 100 MHz z Basys 3
        btnC    : in  std_logic;  -- reset

        ble_rx  : in  std_logic;  -- z TXD modułu PmodBLE do FPGA
        ble_tx  : out std_logic;  -- z FPGA do RXD modułu PmodBLE
        ble_cts : out std_logic;  -- CTS pin PmodBLE (active low) - drive '0' to allow transmit

        led     : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of top is

    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;

    signal led_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Echo pending flag: set when we received a byte but TX was busy
    signal echo_pending : std_logic := '0';

begin

    led <= led_reg;

    -- Drive CTS low so PmodBLE is always allowed to transmit data to FPGA
    ble_cts <= '0';

    uart_receiver : entity work.uart_rx
        generic map (
            CLK_FREQ  => 100_000_000,
            BAUD_RATE => 9_600
        )
        port map (
            clk        => clk,
            rst        => btnC,
            rx         => ble_rx,
            data_out   => rx_data,
            data_valid => rx_valid
        );

    uart_transmitter : entity work.uart_tx
        generic map (
            CLK_FREQ  => 100_000_000,
            BAUD_RATE => 9_600
        )
        port map (
            clk      => clk,
            rst      => btnC,
            data_in  => tx_data,
            tx_start => tx_start,
            tx       => ble_tx,
            tx_busy  => tx_busy
        );

    process(clk)
    begin
        if rising_edge(clk) then

            if btnC = '1' then
                led_reg      <= (others => '0');
                tx_start     <= '0';
                tx_data      <= (others => '0');
                echo_pending <= '0';

            else
                tx_start <= '0';

                if rx_valid = '1' then
                    -- pokaż odebrany bajt na LED-ach
                    led_reg <= rx_data;

                    -- Zapamiętaj dane do odesłania (echo)
                    tx_data <= rx_data;

                    -- odeślij ten sam bajt jako echo
                    if tx_busy = '0' then
                        tx_start <= '1';
                        echo_pending <= '0';
                    else
                        -- TX jest zajęty, zapamiętaj że trzeba odesłać
                        echo_pending <= '1';
                    end if;

                elsif echo_pending = '1' and tx_busy = '0' then
                    -- TX się zwolnił, odeślij zapamiętany bajt
                    tx_start <= '1';
                    echo_pending <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture;
