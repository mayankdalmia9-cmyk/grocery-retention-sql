"""Minimal reader for R .rds/.rda files (XDR format) -> pandas DataFrames.
Handles the vector types used by data frames / tibbles, plus ALTREP compact sequences."""
import bz2, gzip, lzma, struct, sys
import numpy as np, pandas as pd

def _open(path):
    raw = open(path, 'rb').read()
    if raw[:3] == b'BZh': raw = bz2.decompress(raw)
    elif raw[:2] == b'\x1f\x8b': raw = gzip.decompress(raw)
    elif raw[:6] == b'\xfd7zXZ\x00': raw = lzma.decompress(raw)
    return raw

class R:
    def __init__(self, buf):
        self.b, self.p, self.refs = buf, 0, []
    def i(self):
        v = struct.unpack_from('>i', self.b, self.p)[0]; self.p += 4; return v
    def header(self):
        assert self.b[self.p:self.p+2] == b'X\n', self.b[self.p:self.p+5]; self.p += 2
        ver = self.i(); self.i(); self.i()
        if ver == 3: n = self.i(); self.p += n
    def chars(self):
        n = self.i()
        if n == -1: return None
        s = self.b[self.p:self.p+n].decode('utf-8', 'replace'); self.p += n; return s
    def item(self):
        flags = self.i(); t = flags & 0xFF
        has_attr, has_tag = flags & (1 << 9), flags & (1 << 10)
        if t in (254, 242, 253, 241, 251, 247, 0): return None
        if t == 255:
            idx = flags >> 8
            if idx == 0: idx = self.i()
            return self.refs[idx - 1]
        if t == 1:  # symbol
            self.i()  # CHARSXP flags
            s = ('SYM', self.chars()); self.refs.append(s); return s
        if t == 2:  # pairlist
            out = {}
            while True:
                attr = self.item() if has_attr else None
                tag = self.item() if has_tag else None
                val = self.item()
                out[tag[1] if tag else len(out)] = val
                nf = self.i(); nt = nf & 0xFF
                if nt in (254, 0): break
                has_attr, has_tag = nf & (1 << 9), nf & (1 << 10)
                if nt != 2:  # dotted cdr
                    self.p -= 4; self.item(); break
            return out
        if t == 238:  # ALTREP
            info = self.item(); state = self.item(); attr = self.item()
            cls = list(info.values())[0][1] if isinstance(info, dict) else str(info)
            if cls == 'compact_intseq':
                n, start, step = state['v'] if isinstance(state, dict) else state
                v = np.arange(int(start), int(start) + int(n) * int(step), int(step))
            elif cls == 'compact_realseq':
                n, start, step = state
                v = np.arange(start, start + n * step, step)
            elif cls.startswith('wrap_'):
                v = state[0] if isinstance(state, list) else state
            elif cls == 'deferred_string':
                arg = state[0] if isinstance(state, dict) else state
                v = np.array([None if x is None else str(x) for x in np.asarray(arg[0] if isinstance(arg, list) else arg)], dtype=object)
            else:
                raise ValueError('altrep ' + cls)
            return self._wrap(v, attr)
        if t == 9: self.p -= 4; self.i(); return self.chars()  # unreachable path guard
        if t in (10, 13):
            n = self.i(); v = np.frombuffer(self.b, '>i4', n, self.p).astype('int64'); self.p += 4 * n
            v = v.astype('float64'); v[v == -2147483648] = np.nan
            attr = self.item() if has_attr else None
            return self._wrap(v, attr)
        if t == 14:
            n = self.i(); v = np.frombuffer(self.b, '>f8', n, self.p).astype('float64'); self.p += 8 * n
            attr = self.item() if has_attr else None
            return self._wrap(v, attr)
        if t == 16:
            n = self.i(); out = []
            for _ in range(n):
                self.i(); out.append(self.chars())
            attr = self.item() if has_attr else None
            return self._wrap(np.array(out, dtype=object), attr)
        if t == 19:
            n = self.i(); out = [self.item() for _ in range(n)]
            attr = self.item() if has_attr else None
            return self._wrap(out, attr)
        if t == 4:  # environment
            env = {}; self.refs.append(env); self.i()
            self.item(); self.item(); self.item(); self.item(); return env
        raise ValueError(f'unsupported SEXP type {t} at {self.p}')
    def _wrap(self, v, attr):
        if not attr: return v
        cls = attr.get('class')
        cls = list(cls) if cls is not None else []
        if 'factor' in cls:
            lv = attr['levels']
            v = np.asarray(v)
            return np.array([None if np.isnan(x) else lv[int(x) - 1] for x in v], dtype=object)
        if 'data.frame' in cls:
            names = list(attr['names'])
            return pd.DataFrame({k: col for k, col in zip(names, v)})
        if 'POSIXct' in cls:
            return pd.to_datetime(np.asarray(v, dtype='float64'), unit='s', utc=True)
        if 'Date' in cls:
            return pd.to_datetime(np.asarray(v, dtype='float64'), unit='D')
        return v

def read(path):
    buf = _open(path)
    if buf[:4] == b'RDX2' or buf[:4] == b'RDX3':
        r = R(buf[5:]); r.header(); return r.item()
    r = R(buf); r.header(); return r.item()

if __name__ == '__main__':
    obj = read(sys.argv[1])
    if isinstance(obj, dict):
        for k, v in obj.items(): print(k, type(v)); print(v.head() if hasattr(v, 'head') else v)
    else:
        print(obj.head(), obj.shape, obj.dtypes, sep='\n')
