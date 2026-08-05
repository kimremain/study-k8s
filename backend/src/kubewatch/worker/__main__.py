import logging


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    logging.getLogger(__name__).info("worker is not implemented yet")


if __name__ == "__main__":
    main()
