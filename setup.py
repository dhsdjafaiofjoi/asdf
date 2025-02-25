setup(
    name="asdf",
    version="0.1.0",
    py_modules=["asdf"],
    install_requires=[
        "anthropic",
    ],
    entry_points={
        "console_scripts": [
            "asdf=asdf:main",
        ],
    },
    description="A simple CLI tool that uses Anthropic API to generate and execute bash commands",
    author="dhsdjafaiofjoi",
    author_email="d.blazer512@passmail.net",
    url="https://github.com/dhsdjafaiofjoi/asdf",
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Operating System :: POSIX :: Linux",
        "Operating System :: POSIX :: BSD",
        "Operating System :: Unix",
    ],
    python_requires=">=3.6",
)
