import React, { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectItem } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { PieChart, Pie, Cell, Tooltip, Legend } from 'recharts';
import * as XLSX from 'xlsx';
import { auth } from './firebase';
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signOut
} from 'firebase/auth';
import { db } from './firebase';
import {
  collection,
  addDoc,
  onSnapshot,
  doc,
  updateDoc
} from 'firebase/firestore';

const STATUS_OPTIONS = ['Traslado Solicitado', 'En Movimiento', 'Finalizado'];
const ROLES = ['Solicitante', 'Administración', 'Trasladista'];
const COLORS = ['#8884d8', '#82ca9d', '#ffc658'];

const App = () => {
  const [userRole, setUserRole] = useState('Solicitante');
  const [solicitudes, setSolicitudes] = useState([]);
  const [unidad, setUnidad] = useState('');
  const [status, setStatus] = useState('Traslado Solicitado');
  const [ubicacion, setUbicacion] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [user, setUser] = useState(null);
  const [isRegistering, setIsRegistering] = useState(false);
  const [trasladista, setTrasladista] = useState('');

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'solicitudes'), (snapshot) => {
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setSolicitudes(data);
    });
    return () => unsub();
  }, []);

  const handleAuth = async () => {
    try {
      if (isRegistering) {
        await createUserWithEmailAndPassword(auth, email, password);
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
      setEmail('');
      setPassword('');
    } catch (error) {
      alert('Error: ' + error.message);
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
  };

  const crearSolicitud = async () => {
    try {
      await addDoc(collection(db, 'solicitudes'), {
        unidad,
        status,
        ubicacion,
        trasladista
      });
      setUnidad('');
      setUbicacion('');
      setTrasladista('');
      setStatus('Traslado Solicitado');
    } catch (error) {
      alert('Error al guardar: ' + error.message);
    }
  };

  const actualizarStatus = async (id, nuevoStatus) => {
    const ref = doc(db, 'solicitudes', id);
    await updateDoc(ref, { status: nuevoStatus });
  };

  const actualizarUbicacion = async (id, nuevaUbicacion) => {
    const ref = doc(db, 'solicitudes', id);
    await updateDoc(ref, { ubicacion: nuevaUbicacion });
  };

  const exportarExcel = () => {
    const worksheet = XLSX.utils.json_to_sheet(solicitudes);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Solicitudes');
    XLSX.writeFile(workbook, 'reporte_solicitudes.xlsx');
  };

  const renderMap = (direccion) => {
    const url = `https://www.google.com/maps?q=${encodeURIComponent(direccion)}&output=embed`;
    return (
      <iframe
        title="Mapa"
        width="100%"
        height="250"
        frameBorder="0"
        src={url}
        allowFullScreen
      ></iframe>
    );
  };

  const totalSolicitudes = solicitudes.length;
  const porEstado = STATUS_OPTIONS.map((status, index) => ({
    name: status,
    value: solicitudes.filter(s => s.status === status).length,
    fill: COLORS[index % COLORS.length]
  }));
  const porTrasladista = Array.from(
    solicitudes.reduce((map, s) => {
      if (!s.trasladista) return map;
      map.set(s.trasladista, (map.get(s.trasladista) || 0) + 1);
      return map;
    }, new Map())
  );

  if (!user) {
    return (
      <div className="p-4 max-w-md mx-auto">
        <h1 className="text-2xl font-bold mb-4">Iniciar sesión</h1>
        <Input placeholder="Correo electrónico" value={email} onChange={(e) => setEmail(e.target.value)} className="mb-2" />
        <Input type="password" placeholder="Contraseña" value={password} onChange={(e) => setPassword(e.target.value)} className="mb-2" />
        <Button onClick={handleAuth}>{isRegistering ? 'Registrar' : 'Iniciar sesión'}</Button>
        <p className="mt-2 text-sm cursor-pointer text-blue-600" onClick={() => setIsRegistering(!isRegistering)}>
          {isRegistering ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate'}
        </p>
      </div>
    );
  }

  return (
    <div className="p-4 max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Sistema de Traslados de Unidades</h1>
        <Button variant="outline" onClick={handleLogout}>Cerrar sesión</Button>
      </div>

      <div className="mb-4">
        <label className="mr-2 font-semibold">Tipo de Usuario:</label>
        <Select value={userRole} onValueChange={setUserRole}>
          {ROLES.map(rol => (
            <SelectItem key={rol} value={rol}>{rol}</SelectItem>
          ))}
        </Select>
      </div>

      {userRole === 'Administración' && (
        <div className="mb-6 p-4 border rounded-md bg-gray-50">
          <h2 className="text-xl font-semibold mb-4">📊 Dashboard</h2>
          <p className="mb-2 font-medium">Total de solicitudes: {totalSolicitudes}</p>
          <PieChart width={400} height={300}>
            <Pie
              data={porEstado}
              dataKey="value"
              nameKey="name"
              cx="50%"
              cy="50%"
              outerRadius={80}
              label
            >
              {porEstado.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.fill} />
              ))}
            </Pie>
            <Tooltip />
            <Legend />
          </PieChart>
          <h3 className="font-medium mt-4">Por trasladista:</h3>
          <ul>
            {porTrasladista.map(([name, count]) => (
              <li key={name}>{name}: {count}</li>
            ))}
          </ul>
          <Button className="mt-4" onClick={exportarExcel}>📥 Exportar a Excel</Button>
        </div>
      )}

      {/* El resto de la aplicación permanece igual */}
    </div>
  );
};

export default App;
