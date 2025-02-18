"""A logging module wrapper that provides colorization and file logging capabilities"""

import sys
import logging

try:
    import colorama
    from colorama import Fore
except ImportError:
    logging.critical('Please use pip to install colorama library (pip3 install colorama)')
    sys.exit(-1)

class _color_formatter(logging.Formatter):
    """_color_formatter (for internal use within a module) """
    # Change this dictionary to suit your coloring needs!
    COLORS = {
        "WARNING": Fore.YELLOW,
        "ERROR": Fore.RED,
        "DEBUG": Fore.GREEN,
        "INFO": Fore.RESET,
        "CRITICAL": Fore.RED
    }

    def format(self, record):
        color = self.COLORS.get(record.levelname, "")
        if color:
            record.name = color + record.name
            record.levelname = color + record.levelname
            record.msg = color + record.msg
        return logging.Formatter.format(self, record)


class _color_logger(logging.Logger):
    """_color_logger (for internal use within a module) """
    def __init__(self, name):
        logging.Logger.__init__(self, name, logging.DEBUG)

def init(file_log=True, console_log=True):
    """Init colorlog module"""
    colorama.init(autoreset=True)
    logging.setLoggerClass(_color_logger)
    clog = logging.getLogger(__name__)
    if file_log:
        file_formatter = logging.Formatter('%(levelname)s - %(message)s')
        flog = logging.FileHandler('result.log', mode='w')  # Save logs to file
        flog.setFormatter(file_formatter)
        clog.addHandler(flog)

    if console_log:
        color_formatter = _color_formatter('%(levelname)s - %(message)s')
        console = logging.StreamHandler()
        console.setFormatter(color_formatter)
        clog.addHandler(console)

def debug(msg, *args, **kwargs):
    """logging.debug wrapper function"""
    clog = logging.getLogger(__name__)
    clog.debug(msg, *args, **kwargs)

def info(msg, *args, **kwargs):
    """logging.info wrapper function"""
    clog = logging.getLogger(__name__)
    clog.info(msg, *args, **kwargs)

def warning(msg, *args, **kwargs):
    """logging.warning wrapper function"""
    clog = logging.getLogger(__name__)
    clog.warning(msg, *args, **kwargs)

def critical(msg, *args, **kwargs):
    """logging.critical wrapper function"""
    clog = logging.getLogger(__name__)
    clog.critical(msg, *args, **kwargs)

def error(msg, *args, **kwargs):
    """logging.error wrapper function"""
    clog = logging.getLogger(__name__)
    clog.error(msg, *args, **kwargs)

def exception(msg, *args, **kwargs):
    """logging.exception wrapper function"""
    clog = logging.getLogger(__name__)
    clog.error(msg, *args, **kwargs)
