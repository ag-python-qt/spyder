#!/bin/bash -ex

# Adjust PATH in macOS
if [ "$OS" = "macos" ]; then
    PATH=/Users/runner/miniconda3/envs/test/bin:/Users/runner/miniconda3/condabin:$PATH
fi

# Install gdb
if [ "$USE_GDB" = "true" ]; then
    mamba install gdb -c conda-forge -q -y
fi

# Install dependencies
if [ "$USE_CONDA" = "true" ]; then

    # Install Python and main dependencies
    mamba install python=$PYTHON_VERSION -q -y
    mamba env update --file requirements/main.yml

    # Install dependencies per operating system
    if [ "$OS" = "win" ]; then
        # This is necessary for our tests related to conda envs to pass since
        # the release of Mamba 1.1.0
        mamba init
        mamba env update --file requirements/windows.yml
    elif [ "$OS" = "macos" ]; then
        mamba env update --file requirements/macos.yml
    else
        mamba env update --file requirements/linux.yml
    fi

    # Install test dependencies
    mamba env update --file requirements/tests.yml

    # To check our manifest and coverage
    mamba install check-manifest codecov -c conda-forge -q -y

    # Install IPython 8
    mamba install -c conda-forge ipython=8

    # Install PyZMQ 24 to avoid hangs
    mamba install -c conda-forge pyzmq=24
else
    # Update pip and setuptools
    python -m pip install -U pip setuptools wheel build

    # Install Spyder and its dependencies from our setup.py
    pip install -e .[test]

    # Install qtpy from Github
    pip install git+https://github.com/spyder-ide/qtpy.git

    # Install QtAwesome from Github
    pip install git+https://github.com/spyder-ide/qtawesome.git

    # To check our manifest and coverage
    pip install -q check-manifest codecov

    # This allows the test suite to run more reliably on Linux
    if [ "$OS" = "linux" ]; then
        pip uninstall pyqt5 pyqt5-qt5 pyqt5-sip pyqtwebengine pyqtwebengine-qt5 -q -y
        pip install pyqt5==5.12.* pyqtwebengine==5.12.*
    fi

    # Install IPython 8
    pip install ipython==8.7.0

    # Install PyZMQ 24 to avoid hangs
    pip install pyzmq==24.0.1
fi

# Install subrepos from source
python -bb -X dev -W error install_dev_repos.py --not-editable --no-install spyder

# Install boilerplate plugin
pushd spyder/app/tests/spyder-boilerplate
pip install --no-deps -q -e .
popd

# Install Spyder to test it as if it was properly installed.
python -bb -X dev -W error -m build
python -bb -X dev -W error -m pip install --no-deps dist/spyder*.whl

# Create environment for Jedi environments tests
mamba create -n jedi-test-env -q -y python=3.9 flask spyder-kernels
mamba list -n jedi-test-env

# Create environment to test conda activation before launching a spyder kernel
mamba create -n spytest-ž -q -y python=3.9
mamba run -n spytest-ž python -m pip install git+https://github.com/spyder-ide/spyder-kernels.git@master
mamba list -n spytest-ž

# Install pyenv in Posix systems
if [ "$RUN_SLOW" = "false" ]; then
    if [ "$OS" = "linux" ]; then
        curl https://pyenv.run | bash
        $HOME/.pyenv/bin/pyenv install 3.8.1
    fi
fi
