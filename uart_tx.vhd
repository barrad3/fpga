library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 9_600
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        data_in  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic;
        tx       : out std_logic;
        tx_busy  : out std_logic
    );
end entity;

architecture rtl of uart_tx is

    constant BIT_TICKS : integer := CLK_FREQ / BAUD_RATE;

    type state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_t := IDLE;

    signal tick_count : integer range 0 to BIT_TICKS := 0;
    signal bit_index  : integer range 0 to 7 := 0;

    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal tx_line : std_logic := '1';
    signal busy    : std_logic := '0';

begin

    tx <= tx_line;
    tx_busy <= busy;

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state      <= IDLE;
                tick_count <= 0;
                bit_index  <= 0;
                shift_reg  <= (others => '0');
                tx_line    <= '1';
                busy       <= '0';

            else

                case state is

                    when IDLE =>
                        tx_line <= '1';
                        busy <= '0';
                        tick_count <= 0;
                        bit_index <= 0;

                        if tx_start = '1' then
                            shift_reg <= data_in;
                            busy <= '1';
                            tx_line <= '0'; -- start bit
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        if tick_count = BIT_TICKS - 1 then
                            tick_count <= 0;
                            tx_line <= shift_reg(0);
                            bit_index <= 0;
                            state <= DATA_BITS;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when DATA_BITS =>
                        if tick_count = BIT_TICKS - 1 then
                            tick_count <= 0;

                            if bit_index = 7 then
                                tx_line <= '1'; -- stop bit
                                bit_index <= 0;
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                                tx_line <= shift_reg(bit_index + 1);
                            end if;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                    when STOP_BIT =>
                        if tick_count = BIT_TICKS - 1 then
                            tick_count <= 0;
                            tx_line <= '1';
                            busy <= '0';
                            state <= IDLE;
                        else
                            tick_count <= tick_count + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;
