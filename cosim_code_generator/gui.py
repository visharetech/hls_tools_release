import sys
import re
import traceback
from PyQt6 import QtWidgets, QtGui, QtCore
from functions import process_function_head

class MainWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()

        self.input_textbox = QtWidgets.QTextEdit(self)
        self.capture_textbox = QtWidgets.QTextEdit(self)
        self.test_bench_textbox = QtWidgets.QTextEdit(self)
        self.setWindowTitle("Cosim Code Generator")
        # CSS to change font size
        font_size = 14
        self.input_textbox.setStyleSheet(f"font-size: {font_size}px")
        self.capture_textbox.setStyleSheet(f"font-size: {font_size}px")
        self.test_bench_textbox.setStyleSheet(f"font-size: {font_size}px")

        self.process_button = QtWidgets.QPushButton('Process', self)
        self.copy_capture_button = QtWidgets.QPushButton('Copy capture', self)
        self.copy_test_bench_button = QtWidgets.QPushButton('Copy test_bench', self)

        input_layout = QtWidgets.QVBoxLayout()
        input_layout.addWidget(self.input_textbox)
        input_layout.addWidget(self.process_button)

        capture_layout = QtWidgets.QVBoxLayout()
        capture_layout.addWidget(self.capture_textbox)
        capture_layout.addWidget(self.copy_capture_button)

        test_bench_layout = QtWidgets.QVBoxLayout()
        test_bench_layout.addWidget(self.test_bench_textbox)
        test_bench_layout.addWidget(self.copy_test_bench_button)

        layout = QtWidgets.QHBoxLayout()
        layout.addLayout(input_layout)
        layout.addLayout(capture_layout)
        layout.addLayout(test_bench_layout)

        widget = QtWidgets.QWidget()
        widget.setLayout(layout)

        self.setCentralWidget(widget)

        self.process_button.clicked.connect(self.process_text)
        self.copy_capture_button.clicked.connect(self.copy_capture)
        self.copy_test_bench_button.clicked.connect(self.copy_test_bench)

        INPUT_EXAMPLE = 'void setNhtSplitVal_hls(uint8_t flagVal, uint32_t absPartIdx, uint8_t nhtSplitFlagBits_o[64], uint8_t nhtSplitFlagBits_i[64])'
        self.input_textbox.setPlainText(INPUT_EXAMPLE)

        self.create_menus()

    def remove_comments(self, str):
        result = ''
        # Remove all C-style block comments
        lines = re.sub(r"/\*.*?\*/", "", str, flags=re.DOTALL)
        lines = lines.splitlines()

        for line in lines:
            # Remove all C-style line comments
            line = re.sub(r'//.*', '', line)            
            result += '{}\n'.format(line) 
        return result

    def process_text(self):
        try:
            function_string = self.input_textbox.toPlainText()
            #function_string = self.remove_comments(function_string)
            is_remark, func_name, capture_code_string, tb_code_string = process_function_head(function_string, 10000)
            self.capture_textbox.setPlainText(capture_code_string)
            self.test_bench_textbox.setPlainText(tb_code_string)
        except Exception as ex:
            QtWidgets.QMessageBox.warning(self, 'Exception Caught', f'{ex}\n{traceback.format_exc()}')

    def copy_capture(self):
        clipboard = QtGui.QGuiApplication.clipboard()
        clipboard.setText(self.capture_textbox.toPlainText())

    def copy_test_bench(self):
        clipboard = QtGui.QGuiApplication.clipboard()
        clipboard.setText(self.test_bench_textbox.toPlainText())

    def create_menus(self):
        menubar = self.menuBar()
        file_menu = menubar.addMenu('&File')

        about_action = QtGui.QAction('&About', self)
        about_action.triggered.connect(self.show_about_dialog)
        file_menu.addAction(about_action)

    def show_about_dialog(self):
        QtWidgets.QMessageBox.about(self, "About", "Cosimulation code generator. \n By: Ali Deeb")

def main():
    app = QtWidgets.QApplication(sys.argv)

    main = MainWindow()
    main.show()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
