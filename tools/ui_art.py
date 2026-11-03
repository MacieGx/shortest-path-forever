"""Keep screenshot UI art on its reviewed build while data tables use generated data."""


def make(Ui, data_build, art_build, data_tables):
    class Art(Ui):
        _DATA_TABLES = frozenset(data_tables)

        def __init__(self, *args, **kwargs):
            kwargs.setdefault("build", art_build)
            super().__init__(*args, **kwargs)
            self._data = Ui(build=data_build, scale=self.scale)

        def table(self, name, key="ID"):
            if name in self._DATA_TABLES:
                return self._data.table(name, key)
            return super().table(name, key)

    return Art
