import { create } from 'zustand';

export const useStore = create((set, get) => ({
  pgDetails: {
    pgName: 'Elegance PG',
    ownerName: 'Admin',
    totalRooms: 10,
  },
  guests: [
    { id: 1, fullName: 'Rahul Sharma', phone: '+91 9876543210', roomNumber: '101', monthlyRent: 8500, status: 'Active', dueDate: 5 },
    { id: 2, fullName: 'Aman Gupta', phone: '+91 9876543211', roomNumber: '102', monthlyRent: 9000, status: 'Active', dueDate: 2 },
    { id: 3, fullName: 'Priya Singh', phone: '+91 9876543212', roomNumber: '201', monthlyRent: 12000, status: 'Inactive', dueDate: 1 }
  ],
  rooms: [
    { id: 1, roomNumber: '101', type: '2 Sharing', capacity: 2, occupied: 1, status: 'Available' },
    { id: 2, roomNumber: '102', type: '1 Sharing', capacity: 1, occupied: 1, status: 'Full' },
    { id: 3, roomNumber: '201', type: '3 Sharing', capacity: 3, occupied: 0, status: 'Available' },
  ],
  payments: [
    { id: 1, guestId: 1, amount: 8500, date: '2023-10-05', method: 'UPI' },
    { id: 2, guestId: 2, amount: 9000, date: '2023-10-02', method: 'Cash' }
  ],
  
  // Derived state functions
  getStats: () => {
    const { guests, payments, rooms } = get();
    const activeGuests = guests.filter(g => g.status === 'Active');
    const totalExpectedRent = activeGuests.reduce((sum, g) => sum + Number(g.monthlyRent), 0);
    const totalIncome = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    const totalCapacity = rooms.reduce((sum, r) => sum + Number(r.capacity), 0);
    const totalOccupied = rooms.reduce((sum, r) => sum + Number(r.occupied), 0);
    
    // Very simple pending rent calculation for demo
    const pendingRent = totalExpectedRent > totalIncome ? totalExpectedRent - totalIncome : 12500;
    
    return {
      pendingRent,
      totalIncome,
      totalExpense: 4200, // Hardcoded for demo
      occupancyRate: totalCapacity === 0 ? 0 : Math.round((totalOccupied / totalCapacity) * 100),
      totalRooms: rooms.length
    };
  },

  addGuest: (guest) => set((state) => {
    // Update room occupancy
    const updatedRooms = state.rooms.map(r => {
      if (r.roomNumber === guest.roomNumber) {
        const newOccupied = r.occupied + 1;
        return { ...r, occupied: newOccupied, status: newOccupied >= r.capacity ? 'Full' : 'Available' };
      }
      return r;
    });
    return { 
      guests: [...state.guests, { ...guest, id: Date.now(), status: 'Active' }],
      rooms: updatedRooms
    };
  }),
  
  updateGuest: (updatedGuest) => set((state) => ({
    guests: state.guests.map(g => g.id === updatedGuest.id ? updatedGuest : g)
  })),

  deleteGuest: (id) => set((state) => {
    const guest = state.guests.find(g => g.id === id);
    if (!guest) return state;
    
    const updatedRooms = state.rooms.map(r => {
      if (r.roomNumber === guest.roomNumber) {
        const newOccupied = Math.max(0, r.occupied - 1);
        return { ...r, occupied: newOccupied, status: newOccupied >= r.capacity ? 'Full' : 'Available' };
      }
      return r;
    });
    
    return {
      guests: state.guests.filter(g => g.id !== id),
      rooms: updatedRooms
    };
  }),

  addRoom: (room) => set((state) => ({ 
    rooms: [...state.rooms, { ...room, id: Date.now(), occupied: 0, status: 'Available' }] 
  })),
  
  deleteRoom: (id) => set((state) => ({
    rooms: state.rooms.filter(r => r.id !== id)
  })),

  addPayment: (payment) => set((state) => ({
    payments: [{ ...payment, id: Date.now(), date: new Date().toISOString() }, ...state.payments]
  }))
}));
