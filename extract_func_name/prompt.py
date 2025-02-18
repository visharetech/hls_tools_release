def prompt_exit(prompt_str = 'Force to generate verilog code (y/n): '):
    """if user input == N, exit the program"""
    while True:
        user_input = input(prompt_str)
        if user_input.lower() == 'n':
            sys.exit(-1)
        elif user_input.lower() == 'y':
            return

def prompt_question(prompt_str):
    """if user input == N, return False"""
    while True:
        user_input = input(prompt_str)
        if user_input.lower() == 'n':
            return False
        elif user_input.lower() == 'y':
            return True
